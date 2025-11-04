import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crewning/utils/error_handler.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _PaymentBanner extends StatelessWidget {
  const _PaymentBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined,
                  color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                '주차별 3,900원 출전권',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '준비 중',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '주차별 3,900원 결제로 이번 주 경기 출전권을 준비하세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '아직 준비 중인 기능입니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.6),
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor:
                    theme.colorScheme.primary.withOpacity(0.4),
                disabledForegroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('결제 준비 중'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _loadingProfile = true;
  bool _signingOut = false;
  bool _deleting = false;
  String? _profileName;
  String? _profileEmail;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        _loadingProfile = false;
        _profileError = '로그인 정보가 확인되지 않습니다.';
      });
      return;
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      setState(() {
        _loadingProfile = false;
        _profileError = '이메일 정보를 확인할 수 없습니다.';
      });
      return;
    }

    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });

    try {
      final data = await client
          .from('user')
          .select('name, email')
          .eq('email', email)
          .maybeSingle();

      final metadata = user.userMetadata;
      final metadataName = metadata is Map<String, dynamic>
          ? metadata['name'] as String?
          : null;

      setState(() {
        _profileName = (data?['name'] as String?) ?? metadataName ?? '이름 정보 없음';
        _profileEmail = (data?['email'] as String?) ?? email;
        _loadingProfile = false;
      });
    } on PostgrestException catch (error) {
      setState(() {
        _profileError = error.message;
        _loadingProfile = false;
      });
    } catch (error) {
      setState(() {
        _profileError = '프로필 정보를 불러오지 못했습니다: $error';
        _loadingProfile = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _signingOut = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그아웃 중 문제가 발생했습니다: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 확인되지 않습니다. 다시 시도해주세요.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: const Text('정말로 회원을 탈퇴하시겠어요? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('탈퇴'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      await client.functions.invoke('delete-user', body: {'user_id': user.id});
      await client.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')));
    } on FunctionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원 탈퇴 요청에 실패했습니다: $error')));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원 탈퇴 중 문제가 발생했습니다: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            Text(
              '마이페이지',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_loadingProfile)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_profileError != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '프로필을 불러오지 못했습니다.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _profileError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loadProfile,
                          child: const Text('다시 시도'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileName ?? '이름 정보 없음',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _profileEmail ?? '이메일 정보 없음',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const _PaymentBanner(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _signingOut ? null : _handleSignOut,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _signingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('로그아웃'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _deleting ? null : _handleDeleteAccount,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Text('회원 탈퇴'),
            ),
          ],
        ),
      ),
    );
  }
}
