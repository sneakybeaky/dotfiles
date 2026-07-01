// Command nix-cache-check reports which Nix store paths are already available
// in one or more binary caches (substituters).
//
// It resolves the store paths to check either from installables passed on the
// command line (via `nix path-info`), or from a newline-separated list on
// stdin, then issues a HEAD request for each path's `.narinfo` on every cache.
// A 200 means the path can be substituted; a 404 means it would be built
// locally.
//
// Examples:
//
//	# Check the full closure of this machine's home-manager config.
//	nix-cache-check -r .#homeConfigurations."jon@Jons-M1-MacBook-Pro.local".activationPackage
//
//	# Check specific store paths piped in.
//	nix path-info -r nixpkgs#hello | nix-cache-check
//
//	# Only list paths missing from every cache, as plain paths.
//	nix-cache-check -r -missing -quiet .#packages.aarch64-darwin.default
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"sort"
	"strings"
	"sync"
	"time"
)

type options struct {
	caches    []string
	recursive bool
	evalMode  bool
	jobs      int
	timeout   time.Duration
	jsonOut   bool
	missing   bool
	quiet     bool
}

// result holds the per-cache availability for a single store path.
type result struct {
	Path string          `json:"path"`
	Hash string          `json:"hash"`
	Hits map[string]bool `json:"hits"` // cache URL -> present
	Err  string          `json:"error,omitempty"`
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return
		}
		fmt.Fprintln(os.Stderr, "nix-cache-check:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	fs := flag.NewFlagSet("nix-cache-check", flag.ContinueOnError)
	var (
		cachesFlag = fs.String("caches", "", "comma-separated cache URLs to query (default: `nix config show substituters`)")
		recursive  = fs.Bool("r", false, "expand each installable to its full closure")
		evalMode   = fs.Bool("eval", false, "resolve output paths by evaluation (`nix derivation show`) instead of\n\t`nix path-info`; works for installables that are not built locally")
		jobs       = fs.Int("j", 16, "number of concurrent requests")
		timeout    = fs.Duration("timeout", 15*time.Second, "per-request timeout")
		jsonOut    = fs.Bool("json", false, "emit results as JSON")
		missing    = fs.Bool("missing", false, "only report paths missing from at least one cache")
		quiet      = fs.Bool("quiet", false, "print bare store paths only (implies -missing unless -json)")
	)
	fs.Usage = func() {
		fmt.Fprintf(fs.Output(), "Usage: nix-cache-check [flags] [installable|store-path ...]\n\n")
		fmt.Fprintf(fs.Output(), "With no arguments, store paths are read from stdin (one per line).\n\n")
		fmt.Fprintf(fs.Output(), "Flags:\n")
		fs.PrintDefaults()
	}
	if err := fs.Parse(args); err != nil {
		return err
	}

	opts := options{
		recursive: *recursive,
		evalMode:  *evalMode,
		jobs:      *jobs,
		timeout:   *timeout,
		jsonOut:   *jsonOut,
		missing:   *missing || (*quiet && !*jsonOut),
		quiet:     *quiet,
	}
	if opts.jobs < 1 {
		opts.jobs = 1
	}

	caches, err := resolveCaches(*cachesFlag)
	if err != nil {
		return err
	}
	if len(caches) == 0 {
		return fmt.Errorf("no caches to query")
	}
	opts.caches = caches

	paths, err := collectPaths(fs.Args(), opts.recursive, opts.evalMode)
	if err != nil {
		return err
	}
	if len(paths) == 0 {
		return fmt.Errorf("no store paths to check (pass installables or pipe paths on stdin)")
	}

	results := checkAll(paths, opts)
	return report(os.Stdout, results, opts)
}

// resolveCaches returns the list of cache URLs to query. If flagVal is empty it
// falls back to Nix's configured substituters, then to a small default set.
func resolveCaches(flagVal string) ([]string, error) {
	if strings.TrimSpace(flagVal) != "" {
		return normalizeCaches(strings.Split(flagVal, ",")), nil
	}
	out, err := exec.Command("nix", "config", "show", "substituters").Output()
	if err == nil {
		if c := normalizeCaches(strings.Fields(string(out))); len(c) > 0 {
			return c, nil
		}
	}
	// Fall back to the caches this flake configures plus the upstream default.
	return normalizeCaches([]string{
		"https://cache.nixos.org",
		"https://cache.numtide.com",
		"https://cache.garnix.io",
	}), nil
}

func normalizeCaches(raw []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, c := range raw {
		c = strings.TrimSpace(strings.TrimRight(c, "/"))
		// Only HTTP(S) caches expose narinfo over the network.
		if !strings.HasPrefix(c, "http://") && !strings.HasPrefix(c, "https://") {
			continue
		}
		if seen[c] {
			continue
		}
		seen[c] = true
		out = append(out, c)
	}
	return out
}

// collectPaths resolves the store paths to check from installable arguments
// (via nix) or from stdin when no arguments are given.
func collectPaths(args []string, recursive, evalMode bool) ([]string, error) {
	if len(args) == 0 {
		return readStdinPaths()
	}
	if evalMode {
		return evalPaths(args, recursive)
	}

	nixArgs := []string{"path-info"}
	if recursive {
		nixArgs = append(nixArgs, "--recursive")
	}
	nixArgs = append(nixArgs, args...)

	cmd := exec.Command("nix", nixArgs...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("nix path-info failed (paths may not be built; try -eval): %w", err)
	}
	return dedupePaths(strings.Fields(string(out))), nil
}

// evalPaths resolves the output store paths of the installables' build-time
// closure using `nix derivation show`, which only requires evaluation and
// therefore works for installables that have not been built locally.
func evalPaths(args []string, recursive bool) ([]string, error) {
	nixArgs := []string{"derivation", "show"}
	if recursive {
		nixArgs = append(nixArgs, "--recursive")
	}
	nixArgs = append(nixArgs, args...)

	cmd := exec.Command("nix", nixArgs...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("nix derivation show failed: %w", err)
	}
	return dedupePaths(parseDerivationOutputs(out)), nil
}

// parseDerivationOutputs extracts every output store path from the JSON emitted
// by `nix derivation show`. It accepts both the modern shape
// ({"derivations": {drv: {...}}}) and the legacy top-level map ({drv: {...}}).
func parseDerivationOutputs(data []byte) []string {
	type derivation struct {
		Outputs map[string]struct {
			Path string `json:"path"`
		} `json:"outputs"`
	}

	var wrapped struct {
		Derivations map[string]derivation `json:"derivations"`
	}
	drvs := map[string]derivation{}
	if err := json.Unmarshal(data, &wrapped); err == nil && len(wrapped.Derivations) > 0 {
		drvs = wrapped.Derivations
	} else {
		_ = json.Unmarshal(data, &drvs)
	}

	var paths []string
	for _, d := range drvs {
		for _, o := range d.Outputs {
			if p := normalizeStorePath(o.Path); p != "" {
				paths = append(paths, p)
			}
		}
	}
	return paths
}

// normalizeStorePath ensures a store path has the /nix/store/ prefix, since
// `nix derivation show` reports output paths without it.
func normalizeStorePath(p string) string {
	p = strings.TrimSpace(p)
	if p == "" {
		return ""
	}
	if strings.HasPrefix(p, "/") {
		return p
	}
	return "/nix/store/" + p
}

func readStdinPaths() ([]string, error) {
	var paths []string
	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		if f := strings.Fields(sc.Text()); len(f) > 0 {
			paths = append(paths, f...)
		}
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	return dedupePaths(paths), nil
}

func dedupePaths(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, p := range in {
		p = strings.TrimSpace(p)
		if p == "" || seen[p] {
			continue
		}
		seen[p] = true
		out = append(out, p)
	}
	sort.Strings(out)
	return out
}

// storeHash extracts the cache key (the leading base32 hash) from a store path,
// e.g. /nix/store/<hash>-hello-2.12.1 -> <hash>.
func storeHash(path string) string {
	base := path
	if i := strings.LastIndex(base, "/"); i >= 0 {
		base = base[i+1:]
	}
	if i := strings.Index(base, "-"); i >= 0 {
		return base[:i]
	}
	return base
}

func checkAll(paths []string, opts options) []result {
	client := &http.Client{Timeout: opts.timeout}
	results := make([]result, len(paths))

	sem := make(chan struct{}, opts.jobs)
	var wg sync.WaitGroup
	for i, p := range paths {
		wg.Add(1)
		go func(i int, p string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			results[i] = checkPath(client, p, opts.caches)
		}(i, p)
	}
	wg.Wait()
	return results
}

func checkPath(client *http.Client, path string, caches []string) result {
	res := result{Path: path, Hash: storeHash(path), Hits: map[string]bool{}}
	for _, cache := range caches {
		present, err := narinfoPresent(client, cache, res.Hash)
		if err != nil {
			if res.Err != "" {
				res.Err += "; "
			}
			res.Err += fmt.Sprintf("%s: %v", cache, err)
			continue
		}
		res.Hits[cache] = present
	}
	return res
}

// narinfoPresent reports whether <cache>/<hash>.narinfo exists. It uses HEAD,
// falling back to GET for caches that don't allow HEAD.
func narinfoPresent(client *http.Client, cache, hash string) (bool, error) {
	url := cache + "/" + hash + ".narinfo"
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	for _, method := range []string{http.MethodHead, http.MethodGet} {
		req, err := http.NewRequestWithContext(ctx, method, url, nil)
		if err != nil {
			return false, err
		}
		resp, err := client.Do(req)
		if err != nil {
			return false, err
		}
		resp.Body.Close()
		switch resp.StatusCode {
		case http.StatusOK:
			return true, nil
		case http.StatusNotFound, http.StatusForbidden:
			// 403 is how some S3-backed caches signal a missing object.
			return false, nil
		case http.StatusMethodNotAllowed:
			continue // retry with GET
		default:
			return false, fmt.Errorf("unexpected status %d", resp.StatusCode)
		}
	}
	return false, fmt.Errorf("unexpected status")
}

func report(w *os.File, results []result, opts options) error {
	if opts.missing {
		filtered := results[:0:0]
		for _, r := range results {
			if r.Err != "" || !cachedEverywhere(r, opts.caches) {
				filtered = append(filtered, r)
			}
		}
		results = filtered
	}

	if opts.jsonOut {
		enc := json.NewEncoder(w)
		enc.SetIndent("", "  ")
		return enc.Encode(results)
	}

	bw := bufio.NewWriter(w)
	defer bw.Flush()

	if opts.quiet {
		for _, r := range results {
			fmt.Fprintln(bw, r.Path)
		}
		return nil
	}

	printTable(bw, results, opts.caches)
	printSummary(bw, results, opts.caches)
	return nil
}

func cachedEverywhere(r result, caches []string) bool {
	if r.Err != "" {
		return false
	}
	for _, c := range caches {
		if !r.Hits[c] {
			return false
		}
	}
	return true
}

func cachedAnywhere(r result, caches []string) bool {
	for _, c := range caches {
		if r.Hits[c] {
			return true
		}
	}
	return false
}

func printTable(w *bufio.Writer, results []result, caches []string) {
	if len(results) == 0 {
		fmt.Fprintln(w, "(no paths)")
		return
	}
	headers := append([]string{"store path"}, shortCacheNames(caches)...)
	rows := make([][]string, 0, len(results))
	for _, r := range results {
		row := []string{shortPath(r.Path)}
		for _, c := range caches {
			row = append(row, mark(r, c))
		}
		rows = append(rows, row)
	}

	widths := make([]int, len(headers))
	for i, h := range headers {
		widths[i] = len(h)
	}
	for _, row := range rows {
		for i, cell := range row {
			if len(cell) > widths[i] {
				widths[i] = len(cell)
			}
		}
	}

	writeRow(w, headers, widths)
	for _, row := range rows {
		writeRow(w, row, widths)
	}
}

func mark(r result, cache string) string {
	if r.Err != "" && len(r.Hits) == 0 {
		return "err"
	}
	if r.Hits[cache] {
		return "yes"
	}
	return "-"
}

func writeRow(w *bufio.Writer, cells []string, widths []int) {
	var b strings.Builder
	for i, cell := range cells {
		if i > 0 {
			b.WriteString("  ")
		}
		b.WriteString(cell)
		for pad := widths[i] - len(cell); pad > 0; pad-- {
			b.WriteByte(' ')
		}
	}
	fmt.Fprintln(w, strings.TrimRight(b.String(), " "))
}

func printSummary(w *bufio.Writer, results []result, caches []string) {
	total := len(results)
	everywhere, anywhere, errored := 0, 0, 0
	perCache := map[string]int{}
	for _, r := range results {
		if r.Err != "" {
			errored++
		}
		if cachedEverywhere(r, caches) {
			everywhere++
		}
		if cachedAnywhere(r, caches) {
			anywhere++
		}
		for _, c := range caches {
			if r.Hits[c] {
				perCache[c]++
			}
		}
	}
	fmt.Fprintln(w)
	fmt.Fprintf(w, "%d paths checked across %d cache(s)\n", total, len(caches))
	for _, c := range caches {
		fmt.Fprintf(w, "  %-24s %d/%d\n", shortCacheName(c), perCache[c], total)
	}
	fmt.Fprintf(w, "cached somewhere: %d  |  cached everywhere: %d  |  missing everywhere: %d",
		anywhere, everywhere, total-anywhere)
	if errored > 0 {
		fmt.Fprintf(w, "  |  errors: %d", errored)
	}
	fmt.Fprintln(w)
}

func shortPath(p string) string {
	const prefix = "/nix/store/"
	if strings.HasPrefix(p, prefix) {
		rest := p[len(prefix):]
		if i := strings.Index(rest, "-"); i >= 0 {
			return rest[i+1:]
		}
		return rest
	}
	return p
}

func shortCacheNames(caches []string) []string {
	out := make([]string, len(caches))
	for i, c := range caches {
		out[i] = shortCacheName(c)
	}
	return out
}

func shortCacheName(c string) string {
	c = strings.TrimPrefix(c, "https://")
	c = strings.TrimPrefix(c, "http://")
	return c
}
