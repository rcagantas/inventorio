class InvAuth {
  final String email;
  final String displayName;
  final String photoUrl;
  final String uid;
  final String googleSignInId;

  String get emailDisplay {
    String display = this.email ?? '';
    display = this.email.endsWith('appleid.com') ? 'hidden email': display;
    return display;
  }

  InvAuth({
    this.email,
    this.displayName,
    this.photoUrl,
    this.uid,
    this.googleSignInId
  });
}