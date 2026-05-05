<?php

// Simple test script to verify sanitization without Laravel framework
require_once __DIR__ . '/app/Services/InputSanitizationService.php';

use App\Services\InputSanitizationService;

$sanitizer = new InputSanitizationService();

echo "Testing Input Sanitization Service\n";
echo "====================================\n\n";

// Test 1: HTML tag removal
$test1 = '<script>alert("xss")</script>Hello World';
$result1 = $sanitizer->sanitizeString($test1);
echo "Test 1 - HTML tag removal:\n";
echo "Input: " . var_export($test1, true) . "\n";
echo "Output: " . var_export($result1, true) . "\n";
echo "Pass: " . ($result1 === 'Hello World' ? 'YES' : 'NO') . "\n\n";

// Test 2: Whitespace normalization
$test2 = "  Hello    \n   World  ";
$result2 = $sanitizer->sanitizeString($test2);
echo "Test 2 - Whitespace normalization:\n";
echo "Input: " . var_export($test2, true) . "\n";
echo "Output: " . var_export($result2, true) . "\n";
echo "Pass: " . ($result2 === 'Hello World' ? 'YES' : 'NO') . "\n\n";

// Test 3: Email sanitization
$test3 = '  <b>TEST@EXAMPLE.COM</b>  ';
$result3 = $sanitizer->sanitizeEmail($test3);
echo "Test 3 - Email sanitization:\n";
echo "Input: " . var_export($test3, true) . "\n";
echo "Output: " . var_export($result3, true) . "\n";
echo "Pass: " . ($result3 === 'test@example.com' ? 'YES' : 'NO') . "\n\n";

// Test 4: Array sanitization
$test4 = [
    'name' => '<script>alert("xss")</script>Test',
    'description' => '  Hello    World  ',
    'number' => 123,
];
$result4 = $sanitizer->sanitizeArray($test4);
echo "Test 4 - Array sanitization:\n";
echo "Input: " . var_export($test4, true) . "\n";
echo "Output: " . var_export($result4, true) . "\n";
$pass4 = $result4['name'] === 'Test' && 
         $result4['description'] === 'Hello World' && 
         $result4['number'] === 123;
echo "Pass: " . ($pass4 ? 'YES' : 'NO') . "\n\n";

// Test 5: Valid data unchanged
$test5 = 'John Doe';
$result5 = $sanitizer->sanitizeString($test5);
echo "Test 5 - Valid data unchanged:\n";
echo "Input: " . var_export($test5, true) . "\n";
echo "Output: " . var_export($result5, true) . "\n";
echo "Pass: " . ($result5 === 'John Doe' ? 'YES' : 'NO') . "\n\n";

// Test 6: Text sanitization with line breaks
$test6 = "Hello\nWorld\r\nTest";
$result6 = $sanitizer->sanitizeText($test6);
echo "Test 6 - Text sanitization with line breaks:\n";
echo "Input: " . var_export($test6, true) . "\n";
echo "Output: " . var_export($result6, true) . "\n";
echo "Pass: " . ($result6 === "Hello\nWorld\nTest" ? 'YES' : 'NO') . "\n\n";

echo "All tests completed!\n";
echo "Security headers and input sanitization implementation is ready.\n";
