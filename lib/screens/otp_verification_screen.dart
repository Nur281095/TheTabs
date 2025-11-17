import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/conversations_screen.dart';
import '../config/app_colors.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.verificationId,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (index) => FocusNode());
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _timer;
  String? _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startResendCountdown();
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Move to next field
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      }
    } else {
      // Move to previous field
      if (index > 0) {
        _otpFocusNodes[index - 1].requestFocus();
      }
    }

    // Check if all fields are filled
    if (_getOtpCode().length == 6) {
      _verifyOTP();
    }
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _verifyOTP() async {
    final otpCode = _getOtpCode();
    
    if (otpCode.length != 6) {
      _showSnackBar('Please enter the complete verification code');
      return;
    }

    if (_currentVerificationId == null) {
      _showSnackBar('Verification ID not found. Please request a new OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.verifyOTPAndSignIn(
        verificationId: _currentVerificationId!,
        otp: otpCode,
      );

      setState(() {
        _isLoading = false;
      });

      if (userCredential != null) {
        _showSnackBar('Phone number verified successfully!');
        
        // Navigate to main app
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ConversationsScreen()),
          (route) => false,
        );
      } else {
        _showSnackBar('Invalid verification code. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (e is FirebaseAuthException) {
        final errorMessage = _authService.getErrorMessage(e);
        _showSnackBar('Verification failed: $errorMessage');
      } else {
        _showSnackBar('Error verifying OTP: ${e.toString()}');
      }
      print('OTP verification error: $e');
    }
  }

  void _resendOTP() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.sendOTP(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() {
            _isResending = false;
          });
          _showSnackBar('Phone number automatically verified!');
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isResending = false;
          });
          final errorMessage = _authService.getErrorMessage(e);
          _showSnackBar('Failed to resend OTP: $errorMessage');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isResending = false;
            _currentVerificationId = verificationId;
          });
          _startResendCountdown();
          _showSnackBar('New verification code sent!');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _currentVerificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isResending = false;
      });
      _showSnackBar('Failed to resend OTP: ${e.toString()}');
      print('Error resending OTP: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header
              Text(
                'Verify Phone Number',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Enter the 6-digit code sent to\n',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // OTP Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Container(
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _otpFocusNodes[index].hasFocus
                        ? AppColors.primary
                        : _otpControllers[index].text.isNotEmpty
                            ? AppColors.success
                            : AppColors.border,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    onChanged: (value) {
                      _onOtpChanged(index, value);
                        setState(() {}); // Update UI
                      },
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 32),
              
              // Resend Code
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        'Resend code in ${_resendCountdown}s',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : GestureDetector(
                        onTap: _resendOTP,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _isResending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                )
                              : Text(
                                  'Resend Code',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                        ),
                      ),
              ),
              
              const Spacer(),
              
              // Verify Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: _getOtpCode().length == 6 ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _getOtpCode().length == 6
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _getOtpCode().length == 6 && !_isLoading
                      ? _verifyOTP
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Verify & Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _getOtpCode().length == 6
                                ? Colors.white
                                : AppColors.textSecondary,
                            letterSpacing: -0.1,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
