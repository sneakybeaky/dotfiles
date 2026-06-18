# Pure reconcile planner for nono packs.
#
# Input  (stdin): the output of `nono list --installed --json`
#                 (a lockfile object with `.packages`, or `{}` on first run).
# Args:
#   $desired : [ { "key": "<ns>/<name>", "version": <string|null> }, ... ]
#   $prune   : boolean -- remove installed packs not present in $desired
#
# Output: { "pull": [<ref>...], "remove": ["<ns>/<name>"...], "keep": ["<ns>/<name>"...] }
#   - pull ref carries "@<version>" only when a version was requested.
#   - a pack is pulled when missing, or when a requested version differs from
#     what is installed. A versionless desire is satisfied by any installed
#     version (upgrades are nono's `update`, not our concern).

(.packages // {}) as $inst

| def ref($d): if $d.version then "\($d.key)@\($d.version)" else $d.key end;

{
  pull: [
    $desired[]
    | . as $d
    | ($inst[$d.key]) as $cur
    | if $cur == null then ref($d)
      elif ($d.version != null and $cur.version != $d.version) then ref($d)
      else empty
      end
  ],

  keep: [
    $desired[]
    | . as $d
    | ($inst[$d.key]) as $cur
    | if ($cur != null and ($d.version == null or $cur.version == $d.version))
      then $d.key else empty end
  ],

  remove: (
    if $prune then
      [ $inst | keys[]
        | select( . as $k | ($desired | any(.key == $k)) | not ) ]
    else [] end
  ),
}
