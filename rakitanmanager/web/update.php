<?php
/**
 * RakitanManager Update Interface
 * Runs from /tmp directory for safety during updates
 */

// Security headers
header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('X-XSS-Protection: 1; mode=block');

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Configuration
define('INSTALLER_SCRIPT', '/usr/share/rakitanmanager/update.sh');
define('PROGRESS_FILE', '/tmp/rakitanmanager_progress.json');
define('LOG_FILE', '/tmp/rakitanmanager_install.log');
define('STATUS_FILE', '/tmp/rakitanmanager_status.json');
define('COMPLETE_FILE', '/tmp/rakitanmanager_install_complete');
define('UPDATE_TIMEOUT', 300); // 5 minutes
define('UPDATE_START_TIME_FILE', '/tmp/rakitanmanager_update_start');

// CSS Styles
$styles = <<<CSS
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
}

.container {
    background: white;
    border-radius: 15px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    width: 100%;
    max-width: 900px;
    overflow: hidden;
}

.header {
    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
    color: white;
    padding: 30px;
    text-align: center;
}

.header h1 {
    font-size: 2.5rem;
    margin-bottom: 10px;
    font-weight: 300;
}

.header p {
    opacity: 0.9;
    font-size: 1.1rem;
}

.content {
    padding: 30px;
}

.progress-container {
    margin-bottom: 30px;
}

.progress-info {
    display: flex;
    justify-content: space-between;
    margin-bottom: 10px;
    font-size: 1.1rem;
}

.progress-bar {
    height: 20px;
    background: #f0f0f0;
    border-radius: 10px;
    overflow: hidden;
    margin-bottom: 5px;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #4facfe 0%, #00f2fe 100%);
    border-radius: 10px;
    transition: width 0.5s ease;
    width: 0%;
}

.progress-status {
    text-align: center;
    font-weight: 600;
    color: #4facfe;
    min-height: 24px;
}

.log-container {
    background: #f8f9fa;
    border-radius: 10px;
    padding: 20px;
    max-height: 300px;
    overflow-y: auto;
    margin-bottom: 20px;
    border: 1px solid #e9ecef;
}

.log-entry {
    padding: 8px 12px;
    margin-bottom: 5px;
    border-radius: 5px;
    font-family: 'Courier New', monospace;
    font-size: 0.9rem;
    border-left: 4px solid #6c757d;
}

.log-entry.info {
    border-left-color: #17a2b8;
    background: #e3f2fd;
}

.log-entry.success {
    border-left-color: #28a745;
    background: #d4edda;
}

.log-entry.warning {
    border-left-color: #ffc107;
    background: #fff3cd;
}

.log-entry.error {
    border-left-color: #dc3545;
    background: #f8d7da;
}

.log-timestamp {
    color: #6c757d;
    font-size: 0.8rem;
    margin-right: 10px;
}

.log-level {
    font-weight: bold;
    margin-right: 10px;
    padding: 2px 8px;
    border-radius: 3px;
    font-size: 0.8rem;
}

.log-level.info { background: #17a2b8; color: white; }
.log-level.success { background: #28a745; color: white; }
.log-level.warning { background: #ffc107; color: black; }
.log-level.error { background: #dc3545; color: white; }

.actions {
    display: flex;
    gap: 10px;
    justify-content: center;
    margin-top: 20px;
}

.btn {
    padding: 12px 30px;
    border: none;
    border-radius: 50px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
}

.btn-primary {
    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
    color: white;
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(0, 0, 0, 0.2);
}

.btn-secondary {
    background: #6c757d;
    color: white;
}

.btn-danger {
    background: #dc3545;
    color: white;
}

.btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none !important;
}

.spinner {
    border: 3px solid rgba(255,255,255,0.3);
    border-top: 3px solid white;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

.status-card {
    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
    color: white;
    padding: 20px;
    border-radius: 10px;
    text-align: center;
    margin-bottom: 20px;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.02); }
    100% { transform: scale(1); }
}

.system-info {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
    margin-bottom: 20px;
}

.info-item {
    background: #f8f9fa;
    padding: 15px;
    border-radius: 8px;
    border-left: 4px solid #4facfe;
}

.info-label {
    font-size: 0.9rem;
    color: #6c757d;
    margin-bottom: 5px;
}

.info-value {
    font-size: 1.1rem;
    font-weight: 600;
    color: #333;
}

@media (max-width: 768px) {
    .container {
        margin: 10px;
    }
    .header {
        padding: 20px;
    }
    .header h1 {
        font-size: 2rem;
    }
    .content {
        padding: 20px;
    }
}
CSS;

// JavaScript for real-time updates
$scripts = <<<JS
let updateInterval;
let isComplete = false;
let logOffset = 0;

function updateProgress() {
    fetch('?action=get_progress&t=' + new Date().getTime())
        .then(response => response.json())
        .then(data => {
            // Update progress bar
            const progressFill = document.getElementById('progressFill');
            const progressText = document.getElementById('progressText');
            const progressStatus = document.getElementById('progressStatus');
            const currentStep = document.getElementById('currentStep');
            
            progressFill.style.width = data.percentage + '%';
            progressText.textContent = data.percentage + '%';
            progressStatus.textContent = data.status.toUpperCase();
            currentStep.textContent = data.current_step;
            
            // Update logs
            updateLogs(data.log);
            
            // Handle completion
            if (data.status === 'completed' || data.status === 'failed') {
                isComplete = true;
                clearInterval(updateInterval);
                
                const statusCard = document.createElement('div');
                statusCard.className = 'status-card';
                statusCard.innerHTML = data.status === 'completed' 
                    ? '<h3>🎉 Update Completed Successfully!</h3><p>You can now return to the main interface.</p>'
                    : '<h3>❌ Update Failed!</h3><p>Check the logs for details and try again.</p>';
                
                document.querySelector('.content').insertBefore(statusCard, document.querySelector('.log-container'));
                
                // Enable buttons
                document.querySelectorAll('.btn').forEach(btn => btn.disabled = false);
                
                // Auto-redirect on success after 5 seconds
                if (data.status === 'completed') {
                    setTimeout(() => {
                        window.location.href = '/rakitanmanager/index.php';
                    }, 5000);
                }
            }
        })
        .catch(error => {
            console.error('Error fetching progress:', error);
        });
}

function updateLogs(logs) {
    const logContainer = document.getElementById('logContainer');
    
    // Only add new logs
    if (logs.length > logOffset) {
        const newLogs = logs.slice(logOffset);
        logOffset = logs.length;
        
        newLogs.forEach(log => {
            const logEntry = document.createElement('div');
            logEntry.className = `log-entry \${log.level.toLowerCase()}`;
            logEntry.innerHTML = `
                <span class="log-timestamp">\${log.timestamp}</span>
                <span class="log-level \${log.level.toLowerCase()}">\${log.level}</span>
                <span>\${log.message}</span>
            `;
            logContainer.appendChild(logEntry);
        });
        
        // Auto-scroll to bottom
        logContainer.scrollTop = logContainer.scrollHeight;
    }
}

function startUpdate() {
    // Disable buttons
    document.querySelectorAll('.btn').forEach(btn => btn.disabled = true);
    
    // Show loading state
    const startBtn = document.getElementById('startBtn');
    startBtn.innerHTML = '<div class="spinner"></div> Starting Update...';
    
    // Start progress updates
    updateInterval = setInterval(updateProgress, 2000);
    
    // Initial update
    updateProgress();
    
    // Start the update process
    fetch('?action=start_update&t=' + new Date().getTime())
        .then(response => response.json())
        .then(data => {
            if (!data.success) {
                alert('Failed to start update: ' + data.message);
            }
        });
}

function restartService() {
    fetch('?action=restart_service&t=' + new Date().getTime())
        .then(response => response.json())
        .then(data => {
            alert(data.message);
        });
}

function viewLogs() {
    window.open('?action=view_logs', '_blank');
}

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    updateProgress();
    
    // Check if update is already running
    fetch('?action=check_status&t=' + new Date().getTime())
        .then(response => response.json())
        .then(data => {
            if (data.running) {
                document.getElementById('startBtn').disabled = true;
                document.getElementById('startBtn').textContent = 'Update Already Running';
                updateInterval = setInterval(updateProgress, 2000);
            }
        });
});
JS;

function checkUpdateStatus() {
    // Check if installer is running
    $isRunning = false;
    
    // Check for PID file or process
    exec('pgrep -f "install_rakitanmanager"', $output, $return);
    if ($return === 0 && !empty($output)) {
        $isRunning = true;
    }
    
    // Check for progress file
    if (file_exists(PROGRESS_FILE)) {
        $progress = json_decode(file_get_contents(PROGRESS_FILE), true);
        if (isset($progress['status']) && $progress['status'] === 'running') {
            $isRunning = true;
        }
    }
    
    return $isRunning;
}

function getProgressData() {
    $default = [
        'status' => 'idle',
        'step' => 0,
        'total_steps' => 9,
        'current_step' => 'Waiting to start',
        'percentage' => 0,
        'message' => '',
        'timestamp' => time(),
        'log' => []
    ];
    
    if (file_exists(PROGRESS_FILE)) {
        $progress = json_decode(file_get_contents(PROGRESS_FILE), true);
        return array_merge($default, $progress);
    }
    
    return $default;
}

function startUpdateProcess() {
    // Check if already running
    if (checkUpdateStatus()) {
        return ['success' => false, 'message' => 'Update is already running'];
    }
    
    // Clean up old files
    @unlink(PROGRESS_FILE);
    @unlink(COMPLETE_FILE);
    
    // Start installer in background
    $command = INSTALLER_SCRIPT . ' > /dev/null 2>&1 &';
    exec($command, $output, $return);
    
    if ($return === 0) {
        // Mark start time
        file_put_contents(UPDATE_START_TIME_FILE, time());
        return ['success' => true, 'message' => 'Update process started'];
    }
    
    return ['success' => false, 'message' => 'Failed to start update process'];
}

// Handle AJAX requests
if (isset($_GET['action'])) {
    header('Content-Type: application/json');
    
    switch ($_GET['action']) {
        case 'get_progress':
            $progress = getProgressData();
            echo json_encode($progress);
            exit;
            
        case 'check_status':
            echo json_encode(['running' => checkUpdateStatus()]);
            exit;
            
        case 'start_update':
            echo json_encode(startUpdateProcess());
            exit;
            
        case 'restart_service':
            exec('/etc/init.d/rakitanmanager restart 2>&1', $output, $return);
            echo json_encode([
                'success' => $return === 0,
                'message' => $return === 0 ? 'Service restarted successfully' : 'Failed to restart service: ' . implode("\n", $output)
            ]);
            exit;
            
        case 'view_logs':
            if (file_exists(LOG_FILE)) {
                header('Content-Type: text/plain');
                readfile(LOG_FILE);
            } else {
                echo "No log file found.";
            }
            exit;
    }
}

// Main HTML Page
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RakitanManager - System Update</title>
    <style><?php echo $styles; ?></style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-sync-alt"></i> System Update</h1>
            <p>Updating RakitanManager to the latest version</p>
        </div>
        
        <div class="content">
            <div class="progress-container">
                <div class="progress-info">
                    <span>Update Progress</span>
                    <span id="progressText">0%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
                <div class="progress-status">
                    <span id="currentStep">Preparing update...</span> - 
                    <span id="progressStatus">IDLE</span>
                </div>
            </div>
            
            <div class="log-container" id="logContainer">
                <!-- Logs will be loaded here -->
            </div>
            
            <div class="actions">
                <button id="startBtn" class="btn btn-primary" onclick="startUpdate()">
                    <i class="fas fa-play"></i> Start Update
                </button>
                
                <a href="/rakitanmanager/index.php" class="btn btn-secondary">
                    <i class="fas fa-arrow-left"></i> Back to App
                </a>
            </div>
        </div>
    </div>
    
    <script><?php echo $scripts; ?></script>
</body>
</html>