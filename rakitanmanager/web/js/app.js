let modemsData = [];
let currentEditModem = null;

// Initialize the app
document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
});

function initializeApp() {
    // Initial data load
    loadSystemStatus();
    loadModems();
    loadNetworkStats();

    // Set up intervals for periodic updates
    setInterval(loadNetworkStats, 3000);

    // Add event listeners
    document.getElementById('add-modem-btn').addEventListener('click', () => openModal());
    document.getElementById('modal-overlay').addEventListener('click', (e) => {
        if (e.target.id === 'modal-overlay') {
            closeModal();
        }
    });
    document.getElementById('modem-form').addEventListener('submit', saveModem);
}

// API Calls
async function loadSystemStatus() {
    try {
        const response = await fetch('?api=get_system_status');
        const data = await response.json();
        updateDashboard(data);
    } catch (error) {
        console.error('Error loading system status:', error);
    }
}

async function loadModems() {
    try {
        const response = await fetch('?api=get_modems');
        modemsData = await response.json();
        updateModemList(modemsData);
    } catch (error) {
        console.error('Error loading modems:', error);
    }
}

async function loadNetworkStats() {
    try {
        const response = await fetch('?api=get_network_stats');
        const data = await response.json();
        updateNetworkStats(data);
    } catch (error) {
        console.error('Error loading network stats:', error);
    }
}

// UI Updates
function updateDashboard(data) {
    const statusEl = document.getElementById('rakitanmanager-status');
    if (statusEl) {
        statusEl.textContent = data.rakitanmanager.enabled ? 'Enabled' : 'Disabled';
        statusEl.className = data.rakitanmanager.enabled ? 'text-green-600' : 'text-red-600';
    }
}

function updateNetworkStats(data) {
    document.getElementById('download-speed').innerHTML = `${data.download_speed} <span class="text-lg">Mbps</span>`;
    document.getElementById('upload-speed').innerHTML = `${data.upload_speed} <span class="text-lg">Mbps</span>`;
    document.getElementById('data-usage').innerHTML = `${data.data_usage} <span class="text-lg">GB</span>`;
}

function updateModemList(modems) {
    const modemList = document.getElementById('modem-list');
    modemList.innerHTML = '';

    if (modems.length === 0) {
        modemList.innerHTML = '<tr><td colspan="5" class="text-center p-4">No modems found</td></tr>';
        return;
    }

    modems.forEach(modem => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td class="p-2">${modem.name}</td>
            <td class="p-2">${modem.device_name}</td>
            <td class="p-2">${modem.method}</td>
            <td class="p-2">${modem.host_ping}</td>
            <td class="p-2 text-center">
                <button class="btn btn-primary btn-sm" onclick="openModal('${modem.id}')">Manage</button>
                <button class="btn btn-danger btn-sm" onclick="deleteModem('${modem.id}')">Delete</button>
            </td>
        `;
        modemList.appendChild(row);
    });
}

// Modal Handling
function openModal(modemId = null) {
    const modal = document.getElementById('modal-overlay');
    const form = document.getElementById('modem-form');
    form.reset();
    currentEditModem = null;

    if (modemId) {
        currentEditModem = modemsData.find(m => m.id === modemId);
        if (currentEditModem) {
            document.getElementById('modal-title').textContent = 'Edit Modem';
            document.getElementById('modem-name').value = currentEditModem.name;
            document.getElementById('device-type').value = currentEditModem.device_name;
            // ... populate other fields ...
        }
    } else {
        document.getElementById('modal-title').textContent = 'Add Modem';
    }

    modal.classList.remove('hidden');
}

function closeModal() {
    const modal = document.getElementById('modal-overlay');
    modal.classList.add('hidden');
}

// Modem Actions
async function saveModem(event) {
    event.preventDefault();

    const formData = new FormData(event.target);
    const modemData = Object.fromEntries(formData.entries());

    if (currentEditModem) {
        modemData.id = currentEditModem.id;
    }

    try {
        const response = await fetch('?api=save_modem', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(modemData),
        });
        const result = await response.json();
        if (result.success) {
            closeModal();
            loadModems();
        } else {
            alert(`Error: ${result.message}`);
        }
    } catch (error) {
        console.error('Error saving modem:', error);
    }
}

async function deleteModem(modemId) {
    if (!confirm('Are you sure you want to delete this modem?')) {
        return;
    }

    try {
        const response = await fetch(`?api=delete_modem&id=${modemId}`);
        const result = await response.json();
        if (result.success) {
            loadModems();
        } else {
            alert(`Error: ${result.message}`);
        }
    } catch (error) {
        console.error('Error deleting modem:', error);
    }
}

function toggleRakitanManager() {
    fetch('?api=toggle_rakitanmanager')
        .then(response => response.json())
        .then(data => {
            loadSystemStatus();
        });
}
