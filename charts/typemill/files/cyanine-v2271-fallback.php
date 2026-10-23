<?php
// Temporary, hash-guarded fix for Typemill v2.27.1's missing-theme-settings
// fallback. Only ephemeral application code is changed, never PVC contents.
require '/var/www/html/system/vendor/autoload.php';
$stdout = fopen('php://stdout', 'w');
$stderr = fopen('php://stderr', 'w');

$defaults = Symfony\Component\Yaml\Yaml::parseFile('/var/www/html/system/typemill/settings/defaults.yaml');
if (($defaults['version'] ?? null) !== '2.27.1') {
    fwrite($stdout, "Cyanine fallback: not v2.27.1; leaving application code unchanged.\n");
    exit(0);
}

$path = '/var/www/html/system/typemill/Models/Settings.php';
$originalHash = 'a6a1a7751e5d735b8a2bea6c802b0407d5d629d0765bbb1ada075a334174044e';
$patchedHash = 'f273572502d6960d4cf45f6a123bce3585e630187918c1d69e77285eca5efe87';
$temporary = null;
$exitCode = 0;
try {
    if (is_link($path) || !is_file($path)) {
        throw new RuntimeException('Settings.php is not a regular, non-symlink file');
    }
    $source = file_get_contents($path);
    if ($source === false) {
        throw new RuntimeException('cannot read Settings.php');
    }
    $hash = hash('sha256', $source);
    if ($hash === $patchedHash) {
        fwrite($stdout, "Cyanine fallback: verified correction already applied.\n");
        exit(0);
    }
    if ($hash !== $originalHash) {
        throw new RuntimeException('unrecognized Settings.php; refusing to modify custom code. Review the image or disable compatibility.cyanineV2271.enabled');
    }
    $before = <<<'CODE'
getObjectSettings('themes', $settings['theme'])
CODE;
    $after = <<<'CODE'
getObjectSettings('themesFolder', $settings['theme'])
CODE;
    $patched = str_replace($before, $after, $source, $count);
    if ($count !== 1 || hash('sha256', $patched) !== $patchedHash) {
        throw new RuntimeException('unexpected correction result');
    }
    $temporary = tempnam(dirname($path), '.cyanine-v2271-');
    if ($temporary === false || dirname($temporary) !== dirname($path)) {
        throw new RuntimeException('cannot create a same-directory temporary file');
    }
    if (file_put_contents($temporary, $patched) !== strlen($patched) ||
        !chmod($temporary, fileperms($path) & 0777) ||
        hash_file('sha256', $temporary) !== $patchedHash ||
        !rename($temporary, $path)) {
        throw new RuntimeException('cannot atomically apply verified correction');
    }
    $temporary = null;
    fwrite($stdout, "Cyanine fallback: corrected v2.27.1 theme settings lookup; persisted settings and themes untouched.\n");
} catch (Throwable $error) {
    fwrite($stderr, 'ERROR: Cyanine fallback: ' . $error->getMessage() . "\n");
    $exitCode = 1;
} finally {
    if (is_string($temporary) && is_file($temporary)) {
        unlink($temporary);
    }
}
exit($exitCode);
