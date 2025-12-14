<?php

function get_initial_data() {
    $rakitanmanager_output = shell_exec("uci -q get rakitanmanager.cfg.enabled 2>/dev/null");
    $rakitanmanager_status = (int)trim($rakitanmanager_output);

    return [
        'rakitanmanager_status' => $rakitanmanager_status,
    ];
}

function handle_api_request() {
    $api = $_GET['api'] ?? '';

    switch ($api) {
        case 'get_system_status':
            get_system_status();
            break;
        case 'get_modems':
            get_modems();
            break;
        case 'get_network_stats':
            get_network_stats();
            break;
        case 'toggle_rakitanmanager':
            toggle_rakitanmanager();
            break;
        case 'save_modem':
            save_modem();
            break;
        case 'delete_modem':
            delete_modem();
            break;
        default:
            json_response(['error' => 'Invalid API endpoint'], 404);
    }
}

function get_system_status() {
    $rakitanmanager_output = shell_exec("uci -q get rakitanmanager.cfg.enabled 2>/dev/null");
    $rakitanmanager_status = (int)trim($rakitanmanager_output);
    $branch_output = shell_exec("uci -q get rakitanmanager.cfg.branch 2>/dev/null");
    $branch_select = trim($branch_output);

    json_response([
        'rakitanmanager' => [
            'enabled' => $rakitanmanager_status,
            'branch' => $branch_select ?: 'main',
        ],
    ]);
}

function get_modems() {
    $modemsFile = '/usr/share/rakitanmanager/modems.json';
    if (!file_exists($modemsFile)) {
        json_response([]);
        return;
    }

    $modems = json_decode(file_get_contents($modemsFile), true);
    if ($modems === null) {
        json_response(['error' => 'Invalid JSON format'], 500);
        return;
    }

    json_response($modems);
}

function get_network_stats() {
    session_start();
    $interface = 'br-lan';
    $procNetDev = '/proc/net/dev';

    if (!file_exists($procNetDev)) {
        json_response(['error' => 'Network stats not available'], 500);
        return;
    }

    $lines = file($procNetDev, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    $stats = null;

    foreach ($lines as $line) {
        if (strpos($line, $interface . ':') !== false) {
            $parts = preg_split('/\s+/', trim($line));
            $stats = [
                'bytes_rx' => (int)$parts[1],
                'bytes_tx' => (int)$parts[9],
                'timestamp' => microtime(true),
            ];
            break;
        }
    }

    if (!$stats) {
        json_response(['error' => "Interface {$interface} not found"], 500);
        return;
    }

    $download_speed = 0;
    $upload_speed = 0;

    if (isset($_SESSION['network_prev'])) {
        $prev = $_SESSION['network_prev'];
        $time_diff = $stats['timestamp'] - $prev['timestamp'];

        if ($time_diff > 0) {
            $rx_diff = $stats['bytes_rx'] - $prev['bytes_rx'];
            $tx_diff = $stats['bytes_tx'] - $prev['bytes_tx'];

            $download_speed = round(($rx_diff * 8) / ($time_diff * 1000000), 2);
            $upload_speed = round(($tx_diff * 8) / ($time_diff * 1000000), 2);
        }
    }

    $_SESSION['network_prev'] = $stats;

    $total_bytes = $stats['bytes_rx'] + $stats['bytes_tx'];
    $data_usage = round($total_bytes / (1024 * 1024 * 1024), 2);

    json_response([
        'download_speed' => $download_speed,
        'upload_speed' => $upload_speed,
        'data_usage' => $data_usage,
    ]);
}

function toggle_rakitanmanager() {
    $current_output = shell_exec("uci -q get rakitanmanager.cfg.enabled 2>/dev/null");
    $current_status = (int)trim($current_output);
    $new_status = $current_status ? 0 : 1;

    shell_exec("uci set rakitanmanager.cfg.enabled={$new_status}");
    shell_exec("uci commit rakitanmanager");

    if ($new_status == 1) {
        shell_exec("/usr/share/rakitanmanager/core-manager.sh -s");
    } else {
        shell_exec("/usr/share/rakitanmanager/core-manager.sh -k");
    }

    json_response(['enabled' => $new_status]);
}

function save_modem() {
    checkAndBlockIfEnabled();
    $modemsFile = '/usr/share/rakitanmanager/modems.json';
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        json_response(['success' => false, 'message' => 'Invalid JSON data'], 400);
    }

    $modems = [];
    if (file_exists($modemsFile)) {
        $modems = json_decode(file_get_contents($modemsFile), true) ?? [];
    }

    if (!isset($input['id']) || empty($input['id'])) {
        $input['id'] = 'modem-' . uniqid();
    }

    $existingIndex = -1;
    foreach ($modems as $index => $modem) {
        if ($modem['id'] === $input['id']) {
            $existingIndex = $index;
            break;
        }
    }

    $now = date('c');
    if ($existingIndex >= 0) {
        $input['updated_at'] = $now;
        $input['created_at'] = $modems[$existingIndex]['created_at'];
        $modems[$existingIndex] = $input;
        $message = 'Modem updated successfully';
    } else {
        $input['created_at'] = $now;
        $input['updated_at'] = $now;
        $modems[] = $input;
        $message = 'Modem created successfully';
    }

    if (file_put_contents($modemsFile, json_encode($modems, JSON_PRETTY_PRINT))) {
        json_response(['success' => true, 'message' => $message, 'modem' => $input]);
    } else {
        json_response(['success' => false, 'message' => 'Failed to save modem data'], 500);
    }
}

function delete_modem() {
    checkAndBlockIfEnabled();
    $modemId = $_GET['id'] ?? '';
    if (empty($modemId)) {
        json_response(['success' => false, 'message' => 'Modem ID required'], 400);
    }

    $modemsFile = '/usr/share/rakitanmanager/modems.json';
    if (!file_exists($modemsFile)) {
        json_response(['success' => false, 'message' => 'Modems file not found'], 404);
    }

    $modems = json_decode(file_get_contents($modemsFile), true);
    if ($modems === null) {
        json_response(['success' => false, 'message' => 'Invalid JSON format'], 500);
    }

    $found = false;
    foreach ($modems as $index => $modem) {
        if ($modem['id'] === $modemId) {
            unset($modems[$index]);
            $modems = array_values($modems);
            $found = true;
            break;
        }
    }

    if (!$found) {
        json_response(['success' => false, 'message' => 'Modem not found'], 404);
    }

    if (file_put_contents($modemsFile, json_encode($modems, JSON_PRETTY_PRINT))) {
        json_response(['success' => true, 'message' => 'Modem deleted successfully']);
    } else {
        json_response(['success' => false, 'message' => 'Failed to delete modem'], 500);
    }
}

function isRakitanManagerEnabled() {
    $status = shell_exec("uci -q get rakitanmanager.cfg.enabled 2>/dev/null");
    return intval(trim($status)) === 1;
}

function checkAndBlockIfEnabled() {
    if (isRakitanManagerEnabled()) {
        json_response([
            'success' => false, 
            'message' => 'Aksi tidak dapat dilakukan ketika Rakitan Manager dalam status ENABLE. Silahkan STOP terlebih dahulu.',
            'blocked' => true
        ], 403);
        exit;
    }
}

function json_response($data, $statusCode = 200) {
    http_response_code($statusCode);
    header('Content-Type: application/json');
    echo json_encode($data);
}

?>