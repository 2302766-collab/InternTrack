<?php

namespace Tests\Unit\Services;

use App\Services\InputSanitizationService;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class InputSanitizationServiceDataProviderTest extends TestCase
{
    private InputSanitizationService $service;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = app(InputSanitizationService::class);
    }

    #[DataProvider('sanitizeStringCases')]
    public function test_sanitize_string_cases(string $input, string $expected): void
    {
        $this->assertSame($expected, $this->service->sanitizeString($input));
    }

    #[DataProvider('sanitizeEmailCases')]
    public function test_sanitize_email_cases(string $input, string $expected): void
    {
        $this->assertSame($expected, $this->service->sanitizeEmail($input));
    }

    #[DataProvider('sanitizeTextCases')]
    public function test_sanitize_text_cases(string $input, string $expected): void
    {
        $this->assertSame($expected, $this->service->sanitizeText($input));
    }

    #[DataProvider('sanitizeArrayCases')]
    public function test_sanitize_array_cases(array $input, array $expected): void
    {
        $this->assertSame($expected, $this->service->sanitizeArray($input));
    }

    public static function sanitizeStringCases(): array
    {
        $cases = [];

        for ($i = 1; $i <= 35; $i++) {
            $cases["plain_text_{$i}"] = [
                "Plain text sample {$i}",
                "Plain text sample {$i}",
            ];
        }

        for ($i = 1; $i <= 25; $i++) {
            $cases["whitespace_normalization_{$i}"] = [
                "  Plain   text\t sample \n {$i}  ",
                "Plain text sample {$i}",
            ];
        }

        $scriptCases = [
            ['<script>alert("x")</script>Hello', 'Hello'],
            ['Before<script>alert(1)</script>After', 'BeforeAfter'],
            ['<SCRIPT>alert("XSS")</SCRIPT>Safe', 'Safe'],
            ['<script type="text/javascript">console.log(1)</script>Body', 'Body'],
            ['Hello<script>evil()</script>World', 'HelloWorld'],
            ['<script>evil()</script><b>Bold</b>', 'Bold'],
            ['<script>evil()</script><i>Italic</i>', 'Italic'],
            ['<script>evil()</script><p>Paragraph</p>', 'Paragraph'],
            ['<script>evil()</script>    Clean', 'Clean'],
            ['<script>evil()</script>' . "\n" . 'Clean', 'Clean'],
        ];

        foreach ($scriptCases as $index => [$input, $expected]) {
            $cases['script_strip_' . ($index + 1)] = [$input, $expected];
        }

        $htmlCases = [
            ['<b>Bold</b>', 'Bold'],
            ['<div>Container</div>', 'Container'],
            ['<span>Inline</span>', 'Inline'],
            ['<a href="https://example.com">Link</a>', 'Link'],
            ['<p>Paragraph <strong>Strong</strong></p>', 'Paragraph Strong'],
            ['<ul><li>One</li><li>Two</li></ul>', 'OneTwo'],
            ['<h1>Header</h1>', 'Header'],
            ['<em>Emphasis</em>', 'Emphasis'],
            ['<code>sample()</code>', 'sample()'],
            ['<small>Small text</small>', 'Small text'],
        ];

        foreach ($htmlCases as $index => [$input, $expected]) {
            $cases['html_tag_strip_' . ($index + 1)] = [$input, $expected];
        }

        $javascriptProtocolCases = [
            ['javascript:alert(1)', 'alert(1)'],
            ['JAVASCRIPT:alert(1)', 'alert(1)'],
            ['Click javascript:alert(1) now', 'Click alert(1) now'],
            ['prefixjavascript:suffix', 'prefixsuffix'],
            ['javascript:javascript:run()', 'run()'],
            ['safe text javascript: value', 'safe text value'],
            ['  javascript:trim test  ', 'trim test'],
            ['javascript:alert(1) javascript:alert(2)', 'alert(1) alert(2)'],
            ['line one' . "\n" . 'javascript:alert(1)', 'line one alert(1)'],
            ['javascript: alert(1)', 'alert(1)'],
        ];

        foreach ($javascriptProtocolCases as $index => [$input, $expected]) {
            $cases['javascript_protocol_strip_' . ($index + 1)] = [$input, $expected];
        }

        $eventAttributeCases = [
            ['onclick=alert(1) Click', 'alert(1) Click'],
            ['onload =doBadThing() body', 'doBadThing() body'],
            ['ONMOUSEOVER=run() hover', 'run() hover'],
            ['prefix onfocus=hack() suffix', 'prefix hack() suffix'],
            ['onchange=doSomething() value', 'doSomething() value'],
            ['onerror=alert(1)', 'alert(1)'],
            ['onsubmit = submitNow()', 'submitNow()'],
            ['keydown onkeydown=track() field', 'keydown track() field'],
            ['onmouseenter=jump() and onmouseleave=stay()', 'jump() and stay()'],
            [' onblur = loseFocus() ', 'loseFocus()'],
        ];

        foreach ($eventAttributeCases as $index => [$input, $expected]) {
            $cases['event_attribute_strip_' . ($index + 1)] = [$input, $expected];
        }

        $entityCases = [
            ['Tom &amp; Jerry', 'Tom & Jerry'],
            ['5 &lt; 10', '5 < 10'],
            ['Use &quot;quotes&quot;', 'Use "quotes"'],
            ['It&#039;s fine', "It's fine"],
            ['Copyright &copy; 2026', 'Copyright © 2026'],
            ['&lt;b&gt;encoded&lt;/b&gt;', '<b>encoded</b>'],
            ['A &amp;&amp; B', 'A && B'],
            ['Price: &#36;99', 'Price: $99'],
            ['Smile: &#128512;', 'Smile: 😀'],
            ['Mix &lt;tag&gt; and text', 'Mix <tag> and text'],
        ];

        foreach ($entityCases as $index => [$input, $expected]) {
            $cases['entity_decode_' . ($index + 1)] = [$input, $expected];
        }

        return $cases;
    }

    public static function sanitizeEmailCases(): array
    {
        $cases = [];

        for ($i = 1; $i <= 20; $i++) {
            $cases["email_case_normalization_{$i}"] = [
                "  USER{$i}@EXAMPLE.COM  ",
                "user{$i}@example.com",
            ];
        }

        $htmlCases = [
            ['<b>ADMIN@MAIL.COM</b>', 'admin@mail.com'],
            ['  <i>STAFF@MAIL.COM</i>  ', 'staff@mail.com'],
            ['<div>OWNER@MAIL.COM</div>', 'owner@mail.com'],
            ['<span>TEAM@MAIL.COM</span>', 'team@mail.com'],
            ['<a href="#">LEAD@MAIL.COM</a>', 'lead@mail.com'],
            ['<p>DEV@MAIL.COM</p>', 'dev@mail.com'],
            ['<strong>OPS@MAIL.COM</strong>', 'ops@mail.com'],
            ['<small>QA@MAIL.COM</small>', 'qa@mail.com'],
            ['<em>HR@MAIL.COM</em>', 'hr@mail.com'],
            ['<code>SUPPORT@MAIL.COM</code>', 'support@mail.com'],
        ];

        foreach ($htmlCases as $index => [$input, $expected]) {
            $cases['email_html_strip_' . ($index + 1)] = [$input, $expected];
        }

        return $cases;
    }

    public static function sanitizeTextCases(): array
    {
        $cases = [];

        for ($i = 1; $i <= 20; $i++) {
            $cases["text_line_endings_{$i}"] = [
                "Line A {$i}\r\nLine B {$i}\rLine C {$i}",
                "Line A {$i}\nLine B {$i}\nLine C {$i}",
            ];
        }

        $htmlCases = [
            ['<p>Hello</p>' . "\n" . '<p>World</p>', 'Hello' . "\n" . 'World'],
            ['<div>Alpha</div>' . "\r\n" . '<div>Beta</div>', "Alpha\nBeta"],
            ['  <b>Title</b>  ', 'Title'],
            ['<script>alert(1)</script>Visible', 'alert(1)Visible'],
            ['Text <span>with</span> tags', 'Text with tags'],
            ['<ul><li>A</li><li>B</li></ul>', 'AB'],
            ['<h1>Header</h1>' . "\r" . 'Body', "Header\nBody"],
            ['<a href="#">Link</a>', 'Link'],
            ['<code>echo 1;</code>', 'echo 1;'],
            ['<small>notes</small>', 'notes'],
        ];

        foreach ($htmlCases as $index => [$input, $expected]) {
            $cases['text_html_strip_' . ($index + 1)] = [$input, $expected];
        }

        return $cases;
    }

    public static function sanitizeArrayCases(): array
    {
        return [
            'array_string_and_non_string_values_1' => [
                [
                    'name' => '<script>alert("x")</script> Alice',
                    'bio' => '  Senior    Intern  ',
                    'count' => 5,
                    'active' => true,
                ],
                [
                    'name' => 'Alice',
                    'bio' => 'Senior Intern',
                    'count' => 5,
                    'active' => true,
                ],
            ],
            'array_string_and_non_string_values_2' => [
                [
                    'title' => '<b>Weekly</b> Report',
                    'note' => 'javascript:review complete',
                    'score' => 98.5,
                    'meta' => null,
                ],
                [
                    'title' => 'Weekly Report',
                    'note' => 'review complete',
                    'score' => 98.5,
                    'meta' => null,
                ],
            ],
            'array_string_and_non_string_values_3' => [
                [
                    'line1' => "  First \n line ",
                    'line2' => 'onclick=alert(1) click',
                    'ids' => [1, 2, 3],
                ],
                [
                    'line1' => 'First line',
                    'line2' => 'alert(1) click',
                    'ids' => [1, 2, 3],
                ],
            ],
            'array_string_and_non_string_values_4' => [
                [
                    'encoded' => 'Tom &amp; Jerry',
                    'safe' => 'clean value',
                    'flag' => false,
                ],
                [
                    'encoded' => 'Tom & Jerry',
                    'safe' => 'clean value',
                    'flag' => false,
                ],
            ],
            'array_string_and_non_string_values_5' => [
                [
                    'summary' => '<p>Line</p><p>Two</p>',
                    'email' => '  USER@MAIL.COM  ',
                    'nested' => ['keep' => 'as-is'],
                ],
                [
                    'summary' => 'LineTwo',
                    'email' => 'USER@MAIL.COM',
                    'nested' => ['keep' => 'as-is'],
                ],
            ],
        ];
    }
}
