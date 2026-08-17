curl -fsSL "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o bw.zip &&
  unzip -q bw.zip -d ~/.local/bin &&
  chmod +x ~/.local/bin/bw &&
  rm bw.zip
