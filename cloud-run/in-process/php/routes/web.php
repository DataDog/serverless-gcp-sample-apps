<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Log;

Route::get('/', function () {
    Log::info('Hello world!');
    return 'Hello World!';
});
