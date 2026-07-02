{ inputs, ... }: {

  mise = final: prev: {
    mise = inputs.pinnedMiseVersion.legacyPackages.${prev.system}.mise;
  };

}
