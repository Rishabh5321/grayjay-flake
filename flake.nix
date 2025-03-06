{
  description = "Grayjay Desktop Application with FHS Environment and FUTO Updater";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = rec {
        # Base Grayjay derivation - extracts the zip file
        grayjay-base = pkgs.stdenv.mkDerivation {
          name = "grayjay-base";
          src = pkgs.fetchurl {
            url = "https://updater.grayjay.app/Apps/Grayjay.Desktop/Grayjay.Desktop-linux-x64.zip";
            sha256 = "sha256-Ahy4Li/rPnSTXaQHO6jbOgJLNUt9OizbFdZITJpiBRI=";
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
            
            # Copy the icon to the share directory
            mkdir -p $out/share/icons
            cp "$out/share/grayjay/Grayjay.Desktop-linux-x64-v5/grayjay.png" $out/share/icons/
          '';
        };

        # Desktop entry files
        grayjay-desktop-files = pkgs.runCommand "grayjay-desktop-files" {} ''
          mkdir -p $out/share/applications
          
          # Grayjay desktop file
          cat > $out/share/applications/grayjay.desktop << EOF
          [Desktop Entry]
          Name=Grayjay
          Type=Application
          GenericName=Desktop Client for Grayjay
          Comment=A desktop client for Grayjay to stream and download video content
          Icon=${grayjay-base}/share/icons/grayjay.png
          Exec=grayjay
          Terminal=false
          Categories=Network;
          Keywords=YouTube;Player;
          StartupNotify=true
          StartupWMClass=Grayjay
          EOF
          
          # FUTO Updater desktop file
          cat > $out/share/applications/futo-updater.desktop << EOF
          [Desktop Entry]
          Name=FUTO Updater
          Type=Application
          GenericName=FUTO Updater Client
          Comment=Update manager for FUTO applications like Grayjay
          Icon=${grayjay-base}/share/icons/grayjay.png
          Exec=grayjay --updater
          Terminal=false
          Categories=System;Utility;
          StartupNotify=true
          StartupWMClass=FUTO.Updater.Client
          EOF
        '';

        # Main Grayjay FHS wrapper
        grayjay-fhs-wrapper = pkgs.writeShellScriptBin "grayjay" ''
          # Check if the --updater flag is present
          RUN_UPDATER=0
          for arg in "$@"; do
            if [ "$arg" = "--updater" ]; then
              RUN_UPDATER=1
              break
            fi
          done
          
          # Strip --updater from arguments if present
          ARGS=()
          for arg in "$@"; do
            if [ "$arg" != "--updater" ]; then
              ARGS+=("$arg")
            fi
          done
          
          # Execute the FHS environment with appropriate arguments
          exec ${grayjay-fhs}/bin/grayjay-fhs ''${RUN_UPDATER:+updater} "''${ARGS[@]}"
        '';

        # FHS environment
        grayjay-fhs = pkgs.buildFHSEnv {
          name = "grayjay-fhs";
          targetPkgs = pkgs: with pkgs; [
            # Dependencies for both Grayjay and FUTO Updater
            libz
            icu
            openssl
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
            dotnet-runtime
            curl
          ];

          # Set environment variables and copy files to a writable directory
          runScript = ''
            # Create a writable directory for Grayjay's runtime files
            export GRAYJAY_DATA_DIR="$HOME/.grayjay"
            mkdir -p "$GRAYJAY_DATA_DIR"

            # Copy the entire Grayjay.Desktop-linux-x64-v5 directory to the writable directory
            GRAYJAY_SRC_DIR="${grayjay-base}/share/grayjay/Grayjay.Desktop-linux-x64-v5"
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
                shift  # Remove the "updater" argument
                exec ./FUTO.Updater.Client "$@"
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
              
              # Then launch Grayjay with any passed arguments
              exec ./Grayjay "$@"
            fi
          '';
        };

        # The final combined package
        grayjay = pkgs.symlinkJoin {
          name = "grayjay";
          paths = [
            grayjay-fhs-wrapper
            grayjay-desktop-files
          ];
        };

        # Set the default package
        default = grayjay;
      };

      apps.${system} = {
        grayjay = {
          type = "app";
          program = "${self.packages.${system}.grayjay}/bin/grayjay";
          meta = {
            description = "Desktop client for Grayjay with integrated FUTO Updater";
            license = pkgs.lib.licenses.unfree;
            platforms = pkgs.lib.platforms.linux;
          };
        };
        
        default = self.apps.${system}.grayjay;
      };
    };
}