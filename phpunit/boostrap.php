<?php
error_reporting(E_ALL);
define('_JEXEC', 1);
$_SERVER['HTTP_HOST'] = 'localhost';
$defines = __DIR__ . '/../defines.php';
include( __DIR__ . '/../defines.php' );

if ( !defined('_JDEFINES' ) ) {
    define('JPATH_BASE', __DIR__ . '../');
}
require_once JPATH_BASE . '/includes/framework.php';
