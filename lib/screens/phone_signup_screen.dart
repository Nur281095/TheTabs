import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';

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
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Header
              Text(
                'Welcome to TABS',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your phone number to get started',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8E8E93),
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Phone Number Input
              Text(
                'Phone Number',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 12),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _phoneFocusNode.hasFocus 
                        ? const Color(0xFF667EEA)
                        : Colors.grey.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Country Code Picker
                    GestureDetector(
                      onTap: _showCountryPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
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
                            Text(
                              '+${_selectedCountry.phoneCode}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Colors.grey.shade600,
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
                          hintStyle: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
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
              
              // Info Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF667EEA).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: const Color(0xFF667EEA),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We\'ll send you a verification code to confirm your number',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF667EEA),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Continue Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _phoneController.text.trim().length >= _getMinPhoneLength()
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF667EEA),
                            const Color(0xFF764BA2),
                          ],
                        )
                      : null,
                  color: _phoneController.text.trim().length >= _getMinPhoneLength()
                      ? null
                      : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _phoneController.text.trim().length >= _getMinPhoneLength()
                      ? [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _phoneController.text.trim().length >= _getMinPhoneLength() && !_isLoading
                      ? _sendOTP
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
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _phoneController.text.trim().length >= _getMinPhoneLength()
                                ? Colors.white
                                : Colors.grey.shade600,
                            letterSpacing: -0.1,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Terms Text
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'By continuing, you agree to our ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style: const TextStyle(
                          color: Color(0xFF667EEA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: Color(0xFF667EEA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
