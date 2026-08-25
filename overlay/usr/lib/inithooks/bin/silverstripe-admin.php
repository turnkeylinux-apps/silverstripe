#!/usr/bin/php
<?php

declare(strict_types=1);

use SilverStripe\Core\CoreKernel;
use SilverStripe\ORM\DB;
use SilverStripe\Security\Member;

const WEBROOT = '/var/www/silverstripe';

chdir(WEBROOT);
require WEBROOT . '/vendor/silverstripe/framework/src/includes/autoload.php';

try {
    $input = json_decode(stream_get_contents(STDIN), true, 3, JSON_THROW_ON_ERROR);
} catch (JsonException $error) {
    fwrite(STDERR, "Invalid Silverstripe administrator input\n");
    exit(1);
}

$email = $input['email'] ?? '';
$password = $input['password'] ?? '';
if (!is_string($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fwrite(STDERR, "Invalid Silverstripe administrator email\n");
    exit(1);
}
if (!is_string($password) || $password === '') {
    fwrite(STDERR, "Silverstripe administrator password is required\n");
    exit(1);
}

DB::setMustUsePrimary();
$kernel = new CoreKernel(BASE_PATH);
$kernel->boot();

try {
    $member = Member::get()->byID(1);
    if (!$member) {
        throw new RuntimeException('Silverstripe administrator record is missing');
    }

    $member->Email = $email;
    $result = $member->changePassword($password);
    if (!$result->isValid()) {
        throw new RuntimeException('Silverstripe rejected the administrator password');
    }
} finally {
    $kernel->shutdown();
}
