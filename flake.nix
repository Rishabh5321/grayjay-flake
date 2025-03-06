{
  description = "Grayjay Desktop Application with FHS Environment and Desktop Entry";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
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

            # Check for FUTO.Updater.Client in the same directory
            FUTO_UPDATER="$out/share/grayjay/Grayjay.Desktop-linux-x64-v5/FUTO.Updater.Client"
            if [ ! -f "$FUTO_UPDATER" ]; then
              echo "Warning: FUTO.Updater.Client not found in the extracted files!"
            else
              chmod +x "$FUTO_UPDATER"
            fi

            # Make the executable and create a symlink in $out/bin
            chmod +x "$GRAYJAY_EXECUTABLE"
            mkdir -p $out/bin
            ln -s "$GRAYJAY_EXECUTABLE" $out/bin/grayjay

            # Copy the icon to the share directory
            mkdir -p $out/share/icons
            cp "$out/share/grayjay/Grayjay.Desktop-linux-x64-v5/grayjay.png" $out/share/icons/
          '';
        };

        grayjay-fhs = pkgs.buildFHSEnv {
          name = "grayjay-fhs";
          targetPkgs = pkgs: with pkgs; [
            # Add all the dependencies Grayjay needs here
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
            
            # Additional dependencies that FUTO Updater might need
            dotnet-runtime
            curl
          ];

          # Set environment variables and copy files to a writable directory
          runScript = ''
            # Create a writable directory for Grayjay's runtime files
            export GRAYJAY_DATA_DIR="$HOME/.grayjay"
            mkdir -p "$GRAYJAY_DATA_DIR"

            # Copy the entire Grayjay.Desktop-linux-x64-v5 directory to the writable directory
            GRAYJAY_SRC_DIR="${self.packages.${system}.grayjay}/share/grayjay/Grayjay.Desktop-linux-x64-v5"
            GRAYJAY_DEST_DIR="$GRAYJAY_DATA_DIR/Grayjay.Desktop-linux-x64-v5"
            
            # Only copy if the directory doesn't exist or is older
            if [ ! -d "$GRAYJAY_DEST_DIR" ] || [ "$GRAYJAY_SRC_DIR" -nt "$GRAYJAY_DEST_DIR" ]; then
              rm -rf "$GRAYJAY_DEST_DIR"
              cp -r "$GRAYJAY_SRC_DIR" "$GRAYJAY_DEST_DIR"
              chmod -R u+w "$GRAYJAY_DEST_DIR"
            fi

            # Check if FUTO.Updater.Client exists
            FUTO_UPDATER="$GRAYJAY_DEST_DIR/FUTO.Updater.Client"
            if [ ! -f "$FUTO_UPDATER" ]; then
              echo "Warning: FUTO.Updater.Client not found!"
            else
              chmod +x "$FUTO_UPDATER"
            fi

            # Check if we should run the updater or the app
            if [ "$1" = "updater" ]; then
              # Run FUTO Updater if it exists
              if [ -f "$FUTO_UPDATER" ]; then
                cd "$GRAYJAY_DEST_DIR"
                exec ./FUTO.Updater.Client
              else
                echo "Error: FUTO.Updater.Client not found!"
                exit 1
              fi
            else
              # Run Grayjay with updater check
              cd "$GRAYJAY_DEST_DIR"
              
              # Launch the FUTO Updater in background first to check for updates if it exists
              if [ -f "$FUTO_UPDATER" ]; then
                "$FUTO_UPDATER" --check-updates &
              fi
              
              # Then launch Grayjay
              exec ./Grayjay
            fi
          '';
        };

        # Create a separate wrapper script for running the updater directly
        futo-updater-fhs = pkgs.writeShellScriptBin "futo-updater-fhs" ''
          exec ${self.packages.${system}.grayjay-fhs}/bin/grayjay-fhs updater
        '';

        # Grayjay desktop file
        grayjay-desktop-file = pkgs.makeDesktopItem {
          name = "Grayjay";
          type = "Application";
          desktopName = "Grayjay";
          genericName = "Desktop Client for Grayjay";
          comment = "A desktop client for Grayjay to stream and download video content";
          icon = "${self.packages.${system}.grayjay}/share/icons/grayjay.png";
          exec = "grayjay-fhs";
          terminal = false;
          categories = [ "Network" ];
          keywords = [ "YouTube" "Player" ];
          startupNotify = true;
          startupWMClass = "Grayjay";
          prefersNonDefaultGPU = false;
        };

        # FUTO Updater desktop file
        futo-updater-desktop-file = pkgs.makeDesktopItem {
          name = "FUTO-Updater";
          type = "Application";
          desktopName = "FUTO Updater";
          genericName = "FUTO Updater Client";
          comment = "Update manager for FUTO applications like Grayjay";
          icon = "${self.packages.${system}.grayjay}/share/icons/grayjay.png";
          exec = "futo-updater-fhs";
          terminal = false;
          categories = [ "System" "Utility" ];
          startupNotify = true;
          startupWMClass = "FUTO.Updater.Client";
        };

        # Combine everything into a single package
        grayjay-with-updater = pkgs.symlinkJoin {
          name = "grayjay-with-updater";
          paths = [
            self.packages.${system}.grayjay-fhs
            self.packages.${system}.futo-updater-fhs
            (pkgs.runCommand "desktop-files" { } ''
              mkdir -p $out/share/applications
              cp ${self.packages.${system}.grayjay-desktop-file}/share/applications/*.desktop $out/share/applications/
              cp ${self.packages.${system}.futo-updater-desktop-file}/share/applications/*.desktop $out/share/applications/
            '')
          ];
        };

        default = self.packages.${system}.grayjay-with-updater;
      };

      apps.${system} = {
        grayjay = {
          type = "app";
          program = "${self.packages.${system}.grayjay-with-updater}/bin/grayjay-fhs";
          meta = {
            description = "Desktop client for Grayjay with integrated FUTO Updater";
            license = pkgs.lib.licenses.unfree; # Adjust the license as needed
            maintainers = [ ]; # Add maintainers if applicable
            platforms = pkgs.lib.platforms.linux;
          };
        };
        
        futo-updater = {
          type = "app";
          program = "${self.packages.${system}.grayjay-with-updater}/bin/futo-updater-fhs";
          meta = {
            description = "FUTO Updater Client for Grayjay";
            license = pkgs.lib.licenses.unfree; # Adjust the license as needed
            maintainers = [ ]; # Add maintainers if applicable
            platforms = pkgs.lib.platforms.linux;
          };
        };
      };
    };
}