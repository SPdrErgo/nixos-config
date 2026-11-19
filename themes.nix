# Colour themes. Select one with:
#   theme <name>        # writes /etc/nixos/theme-local.nix and rebuilds
# or put { name = "<name>"; } into theme-local.nix manually.
#
# Hex colours are given without the leading '#' (RRGGBB). They are used for
# alacritty, fuzzel, niri borders and the ly login screen.
{
  catppuccin-mocha = {
    bg = "1e1e2e";
    fg = "cdd6f4";
    selection = "313244";
    black = "45475a";
    red = "f38ba8";
    green = "a6e3a1";
    yellow = "f9e2af";
    blue = "89b4fa";
    magenta = "f5c2e7";
    cyan = "94e2d5";
    white = "bac2de";
    brightBlack = "585b70";
    brightRed = "f38ba8";
    brightGreen = "a6e3a1";
    brightYellow = "f9e2af";
    brightBlue = "89b4fa";
    brightMagenta = "f5c2e7";
    brightCyan = "94e2d5";
    brightWhite = "a6adc8";
    accent = "a6e3a1";
    cursor = "f5e0dc";
    lyAnimation = "gameoflife";
  };

  catppuccin-latte = {
    bg = "eff1f5";
    fg = "4c4f69";
    selection = "ccd0da";
    black = "5c5f77";
    red = "d20f39";
    green = "40a02b";
    yellow = "df8e1d";
    blue = "1e66f5";
    magenta = "ea76cb";
    cyan = "179299";
    white = "acb0be";
    brightBlack = "6c6f85";
    brightRed = "d20f39";
    brightGreen = "40a02b";
    brightYellow = "df8e1d";
    brightBlue = "1e66f5";
    brightMagenta = "ea76cb";
    brightCyan = "179299";
    brightWhite = "bcc0cc";
    accent = "40a02b";
    cursor = "dc8a78";
    lyAnimation = "gameoflife";
  };

  everforest = {
    bg = "2d353b";
    fg = "d3c6aa";
    selection = "475258";
    black = "475258";
    red = "e67e80";
    green = "a7c080";
    yellow = "dbbc7f";
    blue = "7fbbb3";
    magenta = "d699b6";
    cyan = "83c092";
    white = "d3c6aa";
    brightBlack = "5c6a72";
    brightRed = "e67e80";
    brightGreen = "a7c080";
    brightYellow = "dbbc7f";
    brightBlue = "7fbbb3";
    brightMagenta = "d699b6";
    brightCyan = "83c092";
    brightWhite = "e6e2cc";
    accent = "a7c080";
    cursor = "d3c6aa";
    lyAnimation = "gameoflife";
  };

  gruvbox = {
    bg = "282828";
    fg = "ebdbb2";
    selection = "504945";
    black = "282828";
    red = "cc241d";
    green = "98971a";
    yellow = "d79921";
    blue = "458588";
    magenta = "b16286";
    cyan = "689d6a";
    white = "a89984";
    brightBlack = "928374";
    brightRed = "fb4934";
    brightGreen = "b8bb26";
    brightYellow = "fabd2f";
    brightBlue = "83a598";
    brightMagenta = "d3869b";
    brightCyan = "8ec07c";
    brightWhite = "ebdbb2";
    accent = "b8bb26";
    cursor = "ebdbb2";
    lyAnimation = "gameoflife";
  };

  # Classic green phosphor terminal look; `ly` shows the matrix rain here.
  ascii = {
    bg = "000000";
    fg = "33ff66";
    selection = "003311";
    black = "001100";
    red = "ff5555";
    green = "33ff66";
    yellow = "ffff55";
    blue = "55aaff";
    magenta = "ff77ff";
    cyan = "55ffff";
    white = "ccffcc";
    brightBlack = "005522";
    brightRed = "ff7777";
    brightGreen = "66ff99";
    brightYellow = "ffff99";
    brightBlue = "88ccff";
    brightMagenta = "ffaaff";
    brightCyan = "99ffff";
    brightWhite = "eaffea";
    accent = "33ff66";
    cursor = "33ff66";
    lyAnimation = "matrix";
  };
}
