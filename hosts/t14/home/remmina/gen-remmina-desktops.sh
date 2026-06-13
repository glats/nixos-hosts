#!/bin/zsh
REMMINA_DIR="$HOME/.local/share/remmina"
DESKTOP_DIR="$HOME/.local/share/applications"

for f in "$REMMINA_DIR"/*.remmina; do
	name=$(grep -E '^name=' "$f" | head -1 | cut -d= -f2-)
	server=$(grep -E '^server=' "$f" | head -1 | cut -d= -f2-)
	protocol=$(grep -E '^protocol=' "$f" | head -1 | cut -d= -f2-)

	desktop_file="$DESKTOP_DIR/remmina-${name}.desktop"

	cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=${name}
Comment=${protocol} connection to ${server}
Exec=remmina -c ${f}
Icon=remmina
Categories=Network;RemoteAccess;
Terminal=false
StartupWMClass=remmina
EOF
	print "Creado: $desktop_file"
done
