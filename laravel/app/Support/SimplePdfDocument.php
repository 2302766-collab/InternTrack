<?php

namespace App\Support;

class SimplePdfDocument
{
    private array $commands = [];

    public function text(
        float $x,
        float $y,
        string $text,
        int $fontSize = 12,
        string $font = 'F1',
        string $align = 'left'
    ): void {
        $xPosition = $x;

        if ($align !== 'left') {
            $estimatedWidth = strlen($text) * ($fontSize * 0.5);
            if ($align === 'center') {
                $xPosition -= $estimatedWidth / 2;
            } elseif ($align === 'right') {
                $xPosition -= $estimatedWidth;
            }
        }

        $escaped = $this->escape($text);
        $this->commands[] = sprintf(
            "BT /%s %d Tf 1 0 0 1 %.2F %.2F Tm (%s) Tj ET",
            $font,
            $fontSize,
            $xPosition,
            $y,
            $escaped
        );
    }

    public function line(float $x1, float $y1, float $x2, float $y2, float $width = 1): void
    {
        $this->commands[] = sprintf(
            "%.2F w %.2F %.2F m %.2F %.2F l S",
            $width,
            $x1,
            $y1,
            $x2,
            $y2
        );
    }

    public function rect(float $x, float $y, float $width, float $height): void
    {
        $this->commands[] = sprintf(
            "%.2F %.2F %.2F %.2F re S",
            $x,
            $y,
            $width,
            $height
        );
    }

    public function output(): string
    {
        $content = implode("\n", $this->commands);

        $objects = [
            '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
            '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
            '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >> endobj',
            sprintf(
                "4 0 obj << /Length %d >> stream\n%s\nendstream endobj",
                strlen($content),
                $content
            ),
            '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
            '6 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >> endobj',
        ];

        $pdf = "%PDF-1.4\n";
        $offsets = [0];

        foreach ($objects as $object) {
            $offsets[] = strlen($pdf);
            $pdf .= $object . "\n";
        }

        $xrefPosition = strlen($pdf);
        $pdf .= "xref\n0 " . (count($objects) + 1) . "\n";
        $pdf .= "0000000000 65535 f \n";

        for ($i = 1; $i <= count($objects); $i++) {
            $pdf .= sprintf("%010d 00000 n \n", $offsets[$i]);
        }

        $pdf .= "trailer << /Size " . (count($objects) + 1) . " /Root 1 0 R >>\n";
        $pdf .= "startxref\n{$xrefPosition}\n%%EOF";

        return $pdf;
    }

    private function escape(string $value): string
    {
        return str_replace(
            ['\\', '(', ')', "\r", "\n"],
            ['\\\\', '\\(', '\\)', '', ' '],
            $value
        );
    }
}
