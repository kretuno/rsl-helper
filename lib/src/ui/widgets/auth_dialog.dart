import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/translation_service.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoginMode = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return TranslationService.currentLanguage == Language.ru
            ? 'Неверный формат Email.'
            : TranslationService.currentLanguage == Language.uk
                ? 'Невірний формат Email.'
                : 'Invalid email format.';
      case 'user-disabled':
        return TranslationService.currentLanguage == Language.ru
            ? 'Пользователь заблокирован.'
            : TranslationService.currentLanguage == Language.uk
                ? 'Користувача заблоковано.'
                : 'User account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return TranslationService.currentLanguage == Language.ru
            ? 'Неверный Email или пароль.'
            : TranslationService.currentLanguage == Language.uk
                ? 'Невірний Email або пароль.'
                : 'Invalid email or password.';
      case 'email-already-in-use':
        return TranslationService.currentLanguage == Language.ru
            ? 'Этот Email уже используется другим аккаунтом.'
            : TranslationService.currentLanguage == Language.uk
                ? 'Цей Email вже використовується іншим акаунтом.'
                : 'This email is already in use by another account.';
      case 'weak-password':
        return TranslationService.currentLanguage == Language.ru
            ? 'Пароль слишком простой (минимум 6 символов).'
            : TranslationService.currentLanguage == Language.uk
                ? 'Пароль занадто простий (мінімум 6 символів).'
                : 'Password is too weak (min 6 characters).';
      case 'network-request-failed':
        return TranslationService.currentLanguage == Language.ru
            ? 'Ошибка сети. Проверьте подключение к интернету.'
            : TranslationService.currentLanguage == Language.uk
                ? 'Помилка мережі. Перевірте підключення до інтернету.'
                : 'Network error. Please check your connection.';
      default:
        return TranslationService.currentLanguage == Language.ru
            ? 'Произошла ошибка при авторизации.'
            : TranslationService.currentLanguage == Language.uk
                ? 'Сталася помилка при авторизації.'
                : 'An authentication error occurred.';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLoginMode) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true indicating success
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _mapFirebaseError(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoginMode 
                        ? TranslationService.t('sync_login')
                        : TranslationService.t('sync_register'),
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.red.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: TranslationService.t('sync_email'),
                  labelStyle: GoogleFonts.inter(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return TranslationService.currentLanguage == Language.ru
                        ? 'Введите Email'
                        : TranslationService.currentLanguage == Language.uk
                            ? 'Введіть Email'
                            : 'Enter Email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                    return TranslationService.currentLanguage == Language.ru
                        ? 'Неверный формат Email'
                        : TranslationService.currentLanguage == Language.uk
                            ? 'Невірний формат Email'
                            : 'Invalid Email format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: TranslationService.t('sync_password'),
                  labelStyle: GoogleFonts.inter(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return TranslationService.currentLanguage == Language.ru
                        ? 'Введите пароль'
                        : TranslationService.currentLanguage == Language.uk
                            ? 'Введіть пароль'
                            : 'Enter Password';
                  }
                  if (val.trim().length < 6) {
                    return TranslationService.currentLanguage == Language.ru
                        ? 'Минимум 6 символов'
                        : TranslationService.currentLanguage == Language.uk
                            ? 'Мінімум 6 символів'
                            : 'Min 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  shadowColor: AppColors.gold.withOpacity(0.3),
                  elevation: 8,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black),
                        ),
                      )
                    : Text(
                        _isLoginMode 
                            ? TranslationService.t('sync_sign_in')
                            : TranslationService.t('sync_register'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _isLoginMode 
                      ? TranslationService.t('sync_no_account')
                      : TranslationService.t('sync_has_account'),
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
