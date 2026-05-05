<?php

namespace App\Services;

class InputSanitizationService
{
    /**
     * Sanitize string input by removing HTML tags and normalizing whitespace
     *
     * @param string $input
     * @return string
     */
    public function sanitizeString(string $input): string
    {
        // Remove dangerous script content first
        $sanitized = preg_replace('/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi', '', $input);
        
        // Remove HTML tags completely
        $sanitized = strip_tags($sanitized);
        
        // Remove any remaining HTML entities
        $sanitized = html_entity_decode($sanitized, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        
        // Remove JavaScript-like patterns that might remain
        $sanitized = preg_replace('/javascript:/i', '', $sanitized);
        $sanitized = preg_replace('/on\w+\s*=/i', '', $sanitized);
        
        // Normalize whitespace
        $sanitized = preg_replace('/\s+/', ' ', $sanitized);
        
        // Trim leading/trailing whitespace
        $sanitized = trim($sanitized);
        
        return $sanitized;
    }

    /**
     * Sanitize array of strings
     *
     * @param array $inputs
     * @return array
     */
    public function sanitizeArray(array $inputs): array
    {
        return array_map(function ($input) {
            return is_string($input) ? $this->sanitizeString($input) : $input;
        }, $inputs);
    }

    /**
     * Sanitize email (basic validation and cleanup)
     *
     * @param string $email
     * @return string
     */
    public function sanitizeEmail(string $email): string
    {
        $sanitized = strtolower(trim($email));
        
        // Remove any HTML tags
        $sanitized = strip_tags($sanitized);
        
        return $sanitized;
    }

    /**
     * Sanitize text input while preserving line breaks
     *
     * @param string $input
     * @return string
     */
    public function sanitizeText(string $input): string
    {
        // Remove HTML tags but preserve line breaks
        $sanitized = strip_tags($input);
        
        // Normalize line breaks
        $sanitized = preg_replace('/\r\n|\r/', "\n", $sanitized);
        
        // Trim leading/trailing whitespace
        $sanitized = trim($sanitized);
        
        return $sanitized;
    }

    /**
     * Log sanitized input for security monitoring
     *
     * @param string $field
     * @param mixed $original
     * @param mixed $sanitized
     * @return void
     */
    public function logSanitization(string $field, $original, $sanitized): void
    {
        // Only log if sanitization actually changed the input
        if ($original !== $sanitized) {
            \Log::info('Input sanitized', [
                'field' => $field,
                'original_length' => is_string($original) ? strlen($original) : 0,
                'sanitized_length' => is_string($sanitized) ? strlen($sanitized) : 0,
                'changed' => true,
                'timestamp' => now()->toISOString(),
            ]);
        }
    }
}
