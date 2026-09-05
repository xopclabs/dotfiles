{ palette }:

let
    # Noctalia's custom-palette loader aliases hover to tertiary (mHover is
    # dropped), so tertiary is the hover colour for launcher and control center.
    terminal = {
        background = "#${palette.base00}";
        foreground = "#${palette.base05}";
        cursor = "#${palette.base05}";
        cursorText = "#${palette.base00}";
        selectionBg = "#${palette.base02}";
        selectionFg = "#${palette.base05}";
        normal = {
            black = "#${palette.base00}";
            red = "#${palette.base08}";
            green = "#${palette.base0B}";
            yellow = "#${palette.base0A}";
            blue = "#${palette.base0D}";
            magenta = "#${palette.base0E}";
            cyan = "#${palette.base0C}";
            white = "#${palette.base05}";
        };
        bright = {
            black = "#${palette.base03}";
            red = "#${palette.base08}";
            green = "#${palette.base0B}";
            yellow = "#${palette.base0A}";
            blue = "#${palette.base0D}";
            magenta = "#${palette.base0E}";
            cyan = "#${palette.base07}";
            white = "#${palette.base06}";
        };
    };
in {
    dark = {
        mPrimary = "#${palette.base0F}";
        mOnPrimary = "#${palette.base06}";
        mSecondary = "#${palette.base0C}";
        mOnSecondary = "#${palette.base00}";
        mTertiary = "#${palette.base03}";
        mOnTertiary = "#${palette.base06}";
        mError = "#${palette.base08}";
        mOnError = "#${palette.base00}";
        mSurface = "#${palette.base00}";
        mOnSurface = "#${palette.base06}";
        mSurfaceVariant = "#${palette.base01}";
        mOnSurfaceVariant = "#${palette.base04}";
        mOutline = "#${palette.base03}";
        mShadow = "#${palette.base00}";
        mHover = "#${palette.base03}";
        mOnHover = "#${palette.base06}";
        inherit terminal;
    };
    light = {
        mPrimary = "#${palette.base0F}";
        mOnPrimary = "#${palette.base06}";
        mSecondary = "#${palette.base0C}";
        mOnSecondary = "#${palette.base06}";
        mTertiary = "#${palette.base04}";
        mOnTertiary = "#${palette.base00}";
        mError = "#${palette.base08}";
        mOnError = "#${palette.base06}";
        mSurface = "#${palette.base06}";
        mOnSurface = "#${palette.base00}";
        mSurfaceVariant = "#${palette.base05}";
        mOnSurfaceVariant = "#${palette.base03}";
        mOutline = "#${palette.base04}";
        mShadow = "#${palette.base04}";
        mHover = "#${palette.base04}";
        mOnHover = "#${palette.base00}";
        terminal = terminal // {
            background = "#${palette.base06}";
            foreground = "#${palette.base00}";
            cursor = "#${palette.base00}";
            cursorText = "#${palette.base06}";
            selectionBg = "#${palette.base04}";
            selectionFg = "#${palette.base00}";
        };
    };
}
