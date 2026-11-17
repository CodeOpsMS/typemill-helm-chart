<?php
// Disposable kind-only authentication regression; credentials arrive on stdin.
declare(strict_types=1);

use Symfony\Component\Yaml\Yaml;
use Typemill\Models\User;

function requireCondition(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function localPath(string $url): string
{
    $parts = parse_url($url);
    requireCondition(is_array($parts), 'Invalid local redirect or form action');
    requireCondition(!isset($parts['host']) || $parts['host'] === '127.0.0.1', 'Non-local HTTP target refused');
    requireCondition(!isset($parts['scheme']) || $parts['scheme'] === 'http', 'Unexpected HTTP scheme');
    requireCondition(!isset($parts['port']) || $parts['port'] === 80, 'Unexpected HTTP port');
    $path = $parts['path'] ?? '';
    requireCondition(str_starts_with($path, '/tm/'), 'Unexpected authentication path');
    return $path . (isset($parts['query']) ? '?' . $parts['query'] : '');
}

function newClient(): CurlHandle
{
    $client = curl_init();
    requireCondition($client !== false, 'Cannot create local HTTP client');
    curl_setopt($client, CURLOPT_COOKIEFILE, '');
    return $client;
}

function request(CurlHandle $client, string $path, ?array $fields = null, string $referer = ''): array
{
    $path = localPath($path);
    curl_setopt_array($client, [
        CURLOPT_URL => 'http://127.0.0.1' . $path,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_HTTPGET => true,
        CURLOPT_REFERER => 'http://127.0.0.1' . ($referer ?: $path),
    ]);
    if ($fields !== null) {
        curl_setopt($client, CURLOPT_POST, true);
        curl_setopt($client, CURLOPT_POSTFIELDS, http_build_query($fields));
    }
    $body = curl_exec($client);
    requireCondition($body !== false, 'Local authentication request failed');
    return [
        'status' => curl_getinfo($client, CURLINFO_HTTP_CODE),
        'location' => curl_getinfo($client, CURLINFO_REDIRECT_URL),
        'body' => $body,
    ];
}

function submitForm(CurlHandle $client, string $path, array $values): array
{
    $page = request($client, $path);
    requireCondition($page['status'] === 200, 'Authentication form did not return HTTP 200');
    $document = new DOMDocument();
    requireCondition($document->loadHTML($page['body'], LIBXML_NONET | LIBXML_NOERROR | LIBXML_NOWARNING), 'Invalid authentication form');
    foreach ($document->getElementsByTagName('form') as $form) {
        $fields = [];
        foreach ($form->getElementsByTagName('input') as $input) {
            if ($input->hasAttribute('name') && !$input->hasAttribute('disabled')) {
                $fields[$input->getAttribute('name')] = $input->getAttribute('value');
            }
        }
        if (array_key_exists('username', $fields) && array_key_exists('password', $fields)) {
            $fields = array_merge($fields, $values, ['personal-honey-mail' => '']);
            return request($client, localPath($form->getAttribute('action')), $fields, $path);
        }
    }
    throw new RuntimeException('Username/password form not found');
}

function storedPassword(string $username, string $password): string
{
    $path = '/var/www/html/settings/users/' . $username . '.yaml';
    requireCondition(is_file($path), 'Administrator user file is missing');
    $data = Yaml::parseFile($path);
    requireCondition(is_array($data) && ($data['userrole'] ?? null) === 'administrator', 'Administrator role missing');
    $hash = $data['password'] ?? null;
    requireCondition(is_string($hash) && password_verify($password, $hash), 'Stored administrator password is missing or invalid');
    return $hash;
}

try {
    requireCondition(PHP_SAPI === 'cli' && getenv('TYPEMILL_CI_AUTH_FIXTURE') === '1', 'Explicit CI fixture flag required');
    requireCondition(chdir('/var/www/html'), 'Cannot enter application directory');
    require '/var/www/html/system/vendor/autoload.php';
    $input = json_decode(stream_get_contents(STDIN), true, 512, JSON_THROW_ON_ERROR);
    $mode = $input['mode'] ?? '';
    $username = $input['username'] ?? '';
    $password = $input['password'] ?? '';
    requireCondition(in_array($mode, ['seed', 'setup', 'login'], true), 'Unknown fixture mode');
    requireCondition(is_string($username) && preg_match('/^ci[a-z0-9]+$/D', $username) === 1, 'Synthetic CI username required');
    requireCondition(is_string($password) && strlen($password) >= 24, 'Synthetic CI password required');
    $userPath = '/var/www/html/settings/users/' . $username . '.yaml';

    if ($mode === 'seed') {
        requireCondition(!file_exists($userPath), 'Refusing to replace an existing test user');
        if (!is_dir(dirname($userPath))) {
            requireCondition(mkdir(dirname($userPath), 0755, true), 'Cannot create test users directory');
        }
        $user = new User();
        requireCondition($user->createUser(['username' => $username, 'email' => $username . '@example.invalid',
            'userrole' => 'administrator', 'password' => $password]), 'Cannot seed upgrade test user');
        foreach ([dirname($userPath), $userPath] as $path) {
            requireCondition(chown($path, 33) && chgrp($path, 33), 'Cannot set test user ownership');
        }
        storedPassword($username, $password);
        echo "Seeded administrator password before upgrade without invoking the old setup login\n";
        exit(0);
    }

    if ($mode === 'setup') {
        requireCondition(!file_exists('/var/www/html/settings/settings.yaml') && !file_exists($userPath), 'Fresh setup fixture is already initialized');
        $client = newClient();
        $result = submitForm($client, '/tm/setup', ['username' => $username,
            'email' => $username . '@example.invalid', 'password' => $password]);
        requireCondition($result['status'] === 302 && localPath($result['location']) === '/tm/system', 'Setup did not redirect to system settings');
        storedPassword($username, $password);
        requireCondition(request($client, '/tm/system')['status'] === 200, 'Setup auto-login did not authenticate the administrator');
        echo "Real HTTP setup and automatic login preserved the administrator password\n";
    }

    $before = storedPassword($username, $password);
    $invalidClient = newClient();
    $invalid = submitForm($invalidClient, '/tm/login', ['username' => $username, 'password' => 'incorrect-' . $password]);
    requireCondition($invalid['status'] === 302 && localPath($invalid['location']) === '/tm/login', 'Incorrect password was not rejected');
    requireCondition(request($invalidClient, '/tm/system')['status'] === 302, 'Incorrect login granted access to system settings');
    requireCondition(storedPassword($username, $password) === $before, 'Rejected login changed the password hash');

    $client = newClient();
    $login = submitForm($client, '/tm/login', ['username' => $username, 'password' => $password]);
    requireCondition($login['status'] === 302, 'Login did not redirect');
    requireCondition(request($client, '/tm/system')['status'] === 200, 'Fresh-session login did not authenticate the administrator');
    requireCondition(storedPassword($username, $password) === $before, 'Successful login changed the password hash');

    $user = new User();
    requireCondition($user->setUser($username) !== false, 'Cannot load public user data');
    requireCondition(!array_key_exists('password', $user->getUserData()), 'Public user data exposed the password hash');
    $user->setValue('firstname', 'CI');
    requireCondition($user->updateUser(), 'Public user update failed');
    requireCondition(storedPassword($username, $password) === $before, 'Public user update removed the stored password');
    requireCondition(chown($userPath, 33) && chgrp($userPath, 33), 'Cannot restore test user ownership');
    echo "Wrong-password rejection, fresh-session login and public user update preserved the password hash\n";
} catch (Throwable $error) {
    fwrite(STDERR, 'FAIL: authentication regression: ' . $error->getMessage() . "\n");
    exit(1);
}
