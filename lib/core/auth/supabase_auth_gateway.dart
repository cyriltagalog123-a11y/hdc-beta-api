// Legacy compatibility note only.
//
// Supabase authentication is not part of the active HDC beta authentication
// path. HDC Flutter now authenticates only through AuthGateway and the HDC-owned
// HTTPS API adapter. Supabase remains a possible provider behind future
// server-side/data adapters and must never be called with privileged credentials
// from the Flutter client.
