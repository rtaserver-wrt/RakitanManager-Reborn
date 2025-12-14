<?php
// Core functions and API handling
require_once 'core/functions.php';

// Handle API requests
if (isset($_GET['api'])) {
    handle_api_request();
    exit;
}

// Get initial data
$initial_data = get_initial_data();
?>
<!doctype html>
<html lang="id" class="h-full">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenWrt Rakitan Manager</title>
    <link rel="stylesheet" href="assets/css/all.min.css">
    <link rel="stylesheet" href="assets/css/style.css">
    <link rel="stylesheet" href="assets/css/tailwind.min.css">
</head>
<body class="bg-gray-100">
    <div id="app" class="flex min-h-screen">
        <!-- Sidebar -->
        <aside class="w-64 bg-white shadow-lg p-4">
            <h1 class="text-2xl font-bold text-primary mb-6">Rakitan Manager</h1>
            <nav>
                <ul>
                    <li class="mb-2"><a href="#" class="flex items-center p-2 rounded-lg hover:bg-gray-200"><i class="fas fa-home w-6"></i>Dashboard</a></li>
                    <li class="mb-2"><a href="#" class="flex items-center p-2 rounded-lg hover:bg-gray-200"><i class="fas fa-wifi w-6"></i>Modem</a></li>
                    <li class="mb-2"><a href="#" class="flex items-center p-2 rounded-lg hover:bg-gray-200"><i class="fas fa-cogs w-6"></i>Dependencies</a></li>
                    <li class="mb-2"><a href="#" class="flex items-center p-2 rounded-lg hover:bg-gray-200"><i class="fas fa-terminal w-6"></i>System Log</a></li>
                </ul>
            </nav>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 p-8">
            <header class="flex justify-between items-center mb-8">
                <h2 class="text-3xl font-bold">Dashboard</h2>
                <div class="flex items-center">
                    <button id="toggle-rakitanmanager" class="btn btn-<?php echo $initial_data['rakitanmanager_status'] ? 'danger' : 'success'; ?>" onclick="toggleRakitanManager()">
                        <?php echo $initial_data['rakitanmanager_status'] ? '<i class="fas fa-stop"></i> STOP' : '<i class="fas fa-play"></i> START'; ?>
                    </button>
                </div>
            </header>

            <!-- Stats -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                <div class="glass-card">
                    <h3 class="text-lg font-semibold mb-2">Download Speed</h3>
                    <p id="download-speed" class="text-3xl font-bold">0.0 <span class="text-lg">Mbps</span></p>
                </div>
                <div class="glass-card">
                    <h3 class="text-lg font-semibold mb-2">Upload Speed</h3>
                    <p id="upload-speed" class="text-3xl font-bold">0.0 <span class="text-lg">Mbps</span></p>
                </div>
                <div class="glass-card">
                    <h3 class="text-lg font-semibold mb-2">Data Usage</h3>
                    <p id="data-usage" class="text-3xl font-bold">0.0 <span class="text-lg">GB</span></p>
                </div>
            </div>

            <!-- Modem List -->
            <div class="glass-card">
                <div class="flex justify-between items-center mb-4">
                    <h3 class="text-xl font-bold">Daftar Modem</h3>
                    <button id="add-modem-btn" class="btn btn-primary">Add Modem</button>
                </div>
                <table class="w-full">
                    <thead>
                        <tr>
                            <th class="text-left p-2">Nama</th>
                            <th class="text-left p-2">Device Name</th>
                            <th class="text-left p-2">Method Ping</th>
                            <th class="text-left p-2">Host Ping</th>
                            <th class="text-center p-2">Action</th>
                        </tr>
                    </thead>
                    <tbody id="modem-list">
                        <!-- Modems will be loaded dynamically -->
                    </tbody>
                </table>
            </div>
        </main>
    </div>

    <!-- Modal -->
    <div id="modal-overlay" class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center hidden">
        <div class="glass-card w-full max-w-2xl">
            <h2 id="modal-title" class="text-2xl font-bold mb-4">Add Modem</h2>
            <form id="modem-form">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label for="modem-name" class="block mb-2">Nama Modem</label>
                        <input type="text" id="modem-name" name="name" class="w-full p-2 border rounded">
                    </div>
                    <div>
                        <label for="device-type" class="block mb-2">Device Name</label>
                        <select id="device-type" name="device_name" class="w-full p-2 border rounded">
                            <option value="Rakitan">Rakitan</option>
                            <option value="HP (Phone)">HP (Phone)</option>
                            <option value="Huawei / Orbit">Huawei / Orbit</option>
                            <option value="Hilink">Hilink</option>
                            <option value="MF90">MF90</option>
                            <option value="Custom Script">Custom Script</option>
                        </select>
                    </div>
                    <div>
                        <label for="method" class="block mb-2">Method</label>
                        <input type="text" id="method" name="method" class="w-full p-2 border rounded">
                    </div>
                    <div>
                        <label for="host-ping" class="block mb-2">Host Ping</label>
                        <input type="text" id="host-ping" name="host_ping" class="w-full p-2 border rounded">
                    </div>
                </div>
                <div class="mt-4 flex justify-end">
                    <button type="submit" class="btn btn-primary">Save</button>
                    <button type="button" class="btn btn-secondary ml-2" onclick="closeModal()">Cancel</button>
                </div>
            </form>
        </div>
    </div>

    <script src="assets/js/app.js"></script>
    <script>
        // Initial data from PHP
        const initialData = <?php echo json_encode($initial_data); ?>;

        document.addEventListener('DOMContentLoaded', () => {
            // Initialize the app
            initializeApp(initialData);
        });
    </script>
</body>
</html>
