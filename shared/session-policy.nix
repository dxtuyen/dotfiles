{
  # Idle deadlines all count from the last input, rather than from each other.
  screenOffSeconds = 300;
  lockSeconds = 600;
  suspendSeconds = 900;
  lockedDisplaySeconds = 10;
  powerCheckSeconds = 30;

  # Automatic sleep remains battery-only. Explicit sleep and lid actions work
  # on AC too; systemd owns the transition from suspend to hibernation.
  sleepAction = "suspend-then-hibernate";
  hibernateDelay = "1h";
}
