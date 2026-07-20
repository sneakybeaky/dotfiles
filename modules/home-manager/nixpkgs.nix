{ inputs, ... }:
{
  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages
      inputs.self.overlays.pinned-mise
      inputs.self.overlays.container
      inputs.self.overlays.llm-agents
    ];
    config = {
      allowUnfree = true;
    };
  };
}
