{ inputs, ... }:
{
  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages
      inputs.self.overlays.pinned-mise
      inputs.llm-agents.overlays.default
    ];
    config = {
      allowUnfree = true;
    };
  };
}
