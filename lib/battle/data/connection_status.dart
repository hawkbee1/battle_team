/// Where the connection to the battle's host stands, as the battle screen
/// needs it.
enum ConnectionStatus {
  /// Finding the host and signing in to it.
  connecting,

  /// Signed in: the view is kept up to date and orders go out.
  connected,

  /// Lost the host; coming back.
  lost,

  /// Stopped for good: the host or Appwrite refused, the battle ended, or
  /// the repository was closed.
  stopped,
}
