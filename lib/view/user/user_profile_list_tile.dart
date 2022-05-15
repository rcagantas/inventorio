
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/auth_provider.dart';

class UserProfileListTile extends ConsumerWidget {
  const UserProfileListTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(authStreamProvider);
    return stream.when(
        data: (user) => ListTile(
          leading: Builder(
            builder: (context) {
              final photoUrl = user?.photoURL ?? '';
              return photoUrl == ''
                ? CircleAvatar(child: Icon(Icons.person),)
                : CircleAvatar(backgroundImage: CachedNetworkImageProvider(user?.photoURL ?? ''),);
            }
          ),
          title: Text(user?.displayName ?? 'Profile Name'),
          subtitle: Text(user?.email ?? ''),
          trailing: IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              await ref.read(actionSinkProvider).signOut();
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
          ),
          onTap: () => Navigator.pushNamed(context, '/profile'),
          onLongPress: () => Navigator.pushNamed(context, '/profile'),
        ),
        error: (error, stack) => Text('Error: $error'),
        loading: () => ListTile(
          leading: CircleAvatar(
            backgroundImage: AssetImage('resources/icons/icon_small.png'),
          ),
          title: Text('Profile Name'),
        ));
  }
}
