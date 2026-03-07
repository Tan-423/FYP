// Global flag: when true, AuthGate will not redirect to MainShell
// even if Firebase has a signed-in user.
// Set to true during the OTP flow (after password check, before OTP verified).
// Set back to false only after OTP is confirmed and final sign-in is done.
bool otpInProgress = false;
