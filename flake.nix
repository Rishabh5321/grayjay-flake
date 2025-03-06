{
  description = "Grayjay Desktop Application with FHS Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      grayjay = pkgs.stdenv.mkDerivation {
        name = "grayjay-desktop";
        src = pkgs.fetchurl {
          url = "https://updater.grayjay.app/Apps/Grayjay.Desktop/Grayjay.Desktop-linux-x64.zip";
          sha256 = "sha256-Ahy4Li/rPnSTXaQHO6jbOgJLNUt9OizbFdZITJpiBRI="; # Replace with the actual SHA-256 hash
        };

        nativeBuildInputs = [ pkgs.unzip ];

        installPhase = ''
          # Extract the .zip file to $out/share/grayjay
          mkdir -p $out/share/grayjay
          unzip $src -d $out/share/grayjay

          # Ensure the Grayjay executable exists
          GRAYJAY_EXECUTABLE="$out/share/grayjay/Grayjay.Desktop-linux-x64-v5/Grayjay"
          if [ ! -f "$GRAYJAY_EXECUTABLE" ]; then
            echo "Error: Grayjay executable not found in the extracted files!"
            exit 1
          fi

          # Make the executable and create a symlink in $out/bin
          chmod +x "$GRAYJAY_EXECUTABLE"
          mkdir -p $out/bin
          ln -s "$GRAYJAY_EXECUTABLE" $out/bin/grayjay
        '';
      };

      grayjay-fhs = pkgs.buildFHSEnv {
        name = "grayjay-fhs";
        targetPkgs = pkgs: with pkgs; [
             libz
    icu
    openssl # For updater

    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb

    gtk3
    glib
    nss
    nspr
    dbus
    atk
    cups
    libdrm
    expat
    libxkbcommon
    pango
    cairo
    udev
    alsa-lib
    mesa
    libGL
    libsecret
        ];

        # Set environment variables and copy files to a writable directory
        runScript = ''
          # Create a writable directory for Grayjay's runtime files
          export GRAYJAY_DATA_DIR="$HOME/.grayjay"
          mkdir -p "$GRAYJAY_DATA_DIR"

          # Copy the entire Grayjay.Desktop-linux-x64-v5 directory to the writable directory
          cp -r ${self.packages.${system}.grayjay}/share/grayjay/Grayjay.Desktop-linux-x64-v5 "$GRAYJAY_DATA_DIR"

          # Ensure the copied files have the correct permissions
          chmod -R u+w "$GRAYJAY_DATA_DIR/Grayjay.Desktop-linux-x64-v5"

          # Run Grayjay from the writable directory
          cd "$GRAYJAY_DATA_DIR/Grayjay.Desktop-linux-x64-v5"
          exec ./Grayjay
        '';
      };

      # Grayjay desktop file
      grayjay-desktop-file = pkgs.makeDesktopItem {
        name = "Grayjay";
        type = "Application";
        desktopName = "Grayjay";
        genericName = "Desktop Client for Grayjay";
        comment = "A desktop client for Grayjay to stream and download video content";
        icon = "${self.packages.${system}.grayjay}/share/grayjay/Grayjay.Desktop-linux-x64-v5/grayjay.png";
        exec = "grayjay-fhs";
        terminal = false;
        categories = [ "Network" ];
        keywords = [
          "YouTube"
          "Player"
        ];
        startupNotify = true;
        startupWMClass = "Grayjay";
        prefersNonDefaultGPU = false;
      };

      default = self.packages.${system}.grayjay-fhs;
    };

    apps.${system} = {
      grayjay = {
        type = "app";
        program = "${self.packages.${system}.grayjay-fhs}/bin/grayjay-fhs";
      };
    };

    defaultPackage.${system} = self.packages.${system}.grayjay-fhs;
    defaultApp.${system} = self.apps.${system}.grayjay;
  };
}