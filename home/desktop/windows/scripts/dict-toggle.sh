#!/usr/bin/env bash
# Use the shared focus-first popup toggle and retain GoldenDict's Qt environment.
set -u
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=Fusion
export QT_PLUGIN_PATH="@qtPlugins@${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
exec @popupToggle@ --match 'io\.github\.xiaoyifang\.goldendict_ng' -- goldendict
