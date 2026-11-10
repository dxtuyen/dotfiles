#!/usr/bin/env bash
# Retain GoldenDict's Qt environment when launching from its popup shortcut.
set -u
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=Fusion
export QT_PLUGIN_PATH="@qtPlugins@${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
exec @popupToggle@ popup-dictionary -- goldendict
