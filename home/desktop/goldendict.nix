{ ... }:

# Keep GoldenDict-ng's Longman article stylesheet in the Home Manager config.
{
  xdg.configFile."goldendict/article-style.css" = {
    source = ../assets/goldendict/longman.css;
    # The current unmanaged file is byte-for-byte identical to this source.
    force = true;
  };
}
