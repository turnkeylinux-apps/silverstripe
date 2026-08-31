<?php

declare(strict_types=1);

use SilverStripe\Assets\File;
use SilverStripe\Core\CoreKernel;
use SilverStripe\ORM\DB;
use SilverStripe\Security\Member;
use SilverStripe\Security\Security;

$options = getopt('', [
    'page-title:',
    'page-segment:',
    'page-content:',
    'asset-title:',
    'asset-target:',
    'asset-source:',
]);
$required = [
    'page-title',
    'page-segment',
    'page-content',
    'asset-title',
    'asset-target',
    'asset-source',
];
foreach ($required as $name) {
    if (!isset($options[$name]) || !is_string($options[$name]) || $options[$name] === '') {
        fwrite(STDERR, "Missing --{$name}\n");
        exit(2);
    }
}
if (!is_file($options['asset-source'])) {
    fwrite(STDERR, "Asset source is not a regular file\n");
    exit(2);
}

const WEBROOT = '/var/www/silverstripe';
chdir(WEBROOT);
require WEBROOT . '/vendor/silverstripe/framework/src/includes/autoload.php';

DB::setMustUsePrimary();
$kernel = new CoreKernel(BASE_PATH);
$kernel->boot();

try {
    $member = Member::get()->byID(1);
    if (!$member) {
        throw new RuntimeException('Silverstripe administrator record is missing');
    }
    Security::setCurrentUser($member);

    $page = Page::create();
    $page->Title = $options['page-title'];
    $page->URLSegment = $options['page-segment'];
    $page->Content = $options['page-content'];
    $page->write();
    $page->publishRecursive();

    $file = File::create();
    $file->setFromLocalFile($options['asset-source'], $options['asset-target']);
    $file->Title = $options['asset-title'];
    $file->write();
    $file->publishRecursive();

    printf("page_id=%d\n", $page->ID);
    printf("page_url=%s\n", $page->Link());
    printf("asset_id=%d\n", $file->ID);
    printf("asset_url=%s\n", $file->getURL());
} finally {
    $kernel->shutdown();
}
