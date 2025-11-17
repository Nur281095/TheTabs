import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';
import '../config/app_colors.dart';

class PhoneSignupScreen extends StatefulWidget {
  const PhoneSignupScreen({super.key});

  @override
  State<PhoneSignupScreen> createState() => _PhoneSignupScreenState();
}

class _PhoneSignupScreenState extends State<PhoneSignupScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _verificationId;
  
  // Default to United States - country_picker will provide the country data
  Country _selectedCountry = Country(
    phoneCode: '1',
    countryCode: 'US',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'United States',
    example: '2012345678',
    displayName: 'United States',
    displayNameNoCountryCode: 'United States',
    e164Key: '',
  );

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _sendOTP() async {
    final phoneNumber = _phoneController.text.trim();
    
    if (phoneNumber.isEmpty || phoneNumber.length < 7) {
      _showSnackBar('Please enter a valid phone number for ${_selectedCountry.name}');
      return;
    }

    final fullPhoneNumber = '+${_selectedCountry.phoneCode}$phoneNumber';
    
    // Additional validation
    if (!RegExp(r'^\+[1-9]\d{10,14}$').hasMatch(fullPhoneNumber)) {
      _showSnackBar('Please enter a valid phone number');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.sendOTP(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showSnackBar('Phone number automatically verified!');
            // Auto sign in here if needed
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            String errorMessage = _authService.getErrorMessage(e);
            _showSnackBar('Verification failed: $errorMessage');
            print('Phone auth error: ${e.code} - ${e.message}');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _verificationId = verificationId;
            });
            
            _showSnackBar('OTP sent to $fullPhoneNumber');
            
            // Navigate to OTP screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  phoneNumber: fullPhoneNumber,
                  verificationId: verificationId,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
            print('Auto-retrieval timeout for verification ID: $verificationId');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Error sending OTP: ${e.toString()}');
        print('Error sending OTP: $e');
      }
    }
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country;
        });
      },
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }

  int _getMinPhoneLength() {
    // Use the example length as a guide for minimum length
    final exampleLength = _selectedCountry.example.length;
    return exampleLength > 7 ? exampleLength - 2 : 7; // Allow some flexibility
  }

  int _getMaxPhoneLength() {
    // Allow 2-3 digits more than the example for flexibility
    return _selectedCountry.example.length + 3;
  }

  String _getPhoneHint() {
    // Use the country's example phone number as hint
    return _selectedCountry.example;
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.phone_android_rounded, color: AppColors.primaryDark),
                      SizedBox(width: 12),
                      Text(
                        'TABS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                const Text(
                  'Welcome to TABS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your phone number to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 36),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Phone Number',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _phoneFocusNode.hasFocus
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showCountryPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.border, width: 1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry.flagEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '+',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _selectedCountry.phoneCode,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Phone Number Field
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_getMaxPhoneLength()),
                          ],
                          decoration: InputDecoration(
                            hintText: _getPhoneHint(),
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          onChanged: (value) {
                            setState(() {}); // Update button state
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We\'ll send you a verification code to confirm your number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _phoneController.text.trim().length >= _getMinPhoneLength() && !_isLoading
                        ? _sendOTP
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _phoneController.text.trim().length >= _getMinPhoneLength()
                          ? AppColors.primary
                          : AppColors.border,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                        : const Text('Continue'),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to our ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
