/**
 * Google Sheets Manager
 * Управление таблицами через командную строку
 *
 * Использование:
 *   node scripts/sheets-manager.js list
 *   node scripts/sheets-manager.js read <spreadsheetId> [sheetName]
 *   node scripts/sheets-manager.js append <spreadsheetId> <sheetName> <jsonData>
 *   node scripts/sheets-manager.js create <title>
 */

const { google } = require('googleapis');
const path = require('path');

const CREDENTIALS_PATH = path.join(__dirname, '..', 'credentials', 'google-credentials.json');

async function getAuthClient() {
  const auth = new google.auth.GoogleAuth({
    keyFile: CREDENTIALS_PATH,
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/drive'
    ]
  });
  return auth.getClient();
}

async function listSheets() {
  const authClient = await getAuthClient();
  const drive = google.drive({ version: 'v3', auth: authClient });

  const res = await drive.files.list({
    q: "mimeType='application/vnd.google-apps.spreadsheet'",
    fields: 'files(id, name, modifiedTime)',
    orderBy: 'modifiedTime desc',
    pageSize: 50
  });

  console.log('\n=== ДОСТУПНЫЕ ТАБЛИЦЫ ===\n');

  if (!res.data.files || res.data.files.length === 0) {
    console.log('Таблицы не найдены.');
    console.log('Расшарьте таблицы на: claude-sheets-bot@tes-2-n8n.iam.gserviceaccount.com');
    return;
  }

  res.data.files.forEach((file, i) => {
    console.log(`${i + 1}. ${file.name}`);
    console.log(`   ID: ${file.id}`);
    console.log(`   Изменён: ${new Date(file.modifiedTime).toLocaleString('ru-RU')}\n`);
  });
}

async function readSheet(spreadsheetId, sheetName = 'Sheet1') {
  const authClient = await getAuthClient();
  const sheets = google.sheets({ version: 'v4', auth: authClient });

  const res = await sheets.spreadsheets.values.get({
    spreadsheetId,
    range: sheetName
  });

  console.log(`\n=== ДАННЫЕ ИЗ ${sheetName} ===\n`);

  const rows = res.data.values;
  if (!rows || rows.length === 0) {
    console.log('Таблица пуста');
    return;
  }

  // Заголовки
  const headers = rows[0];
  console.log('Заголовки:', headers.join(' | '));
  console.log('─'.repeat(60));

  // Данные
  rows.slice(1).forEach((row, i) => {
    console.log(`${i + 1}. ${row.join(' | ')}`);
  });

  console.log(`\nВсего строк: ${rows.length - 1}`);
}

async function appendRow(spreadsheetId, sheetName, jsonData) {
  const authClient = await getAuthClient();
  const sheets = google.sheets({ version: 'v4', auth: authClient });

  const data = JSON.parse(jsonData);
  const values = Array.isArray(data) ? data : [Object.values(data)];

  const res = await sheets.spreadsheets.values.append({
    spreadsheetId,
    range: sheetName,
    valueInputOption: 'USER_ENTERED',
    requestBody: { values }
  });

  console.log(`\n✅ Добавлено строк: ${res.data.updates.updatedRows}`);
  console.log(`Диапазон: ${res.data.updates.updatedRange}`);
}

async function createSheet(title) {
  const authClient = await getAuthClient();
  const sheets = google.sheets({ version: 'v4', auth: authClient });

  const res = await sheets.spreadsheets.create({
    requestBody: {
      properties: { title }
    }
  });

  console.log(`\n✅ Таблица создана!`);
  console.log(`Название: ${res.data.properties.title}`);
  console.log(`ID: ${res.data.spreadsheetId}`);
  console.log(`URL: ${res.data.spreadsheetUrl}`);
}

async function updateCell(spreadsheetId, range, value) {
  const authClient = await getAuthClient();
  const sheets = google.sheets({ version: 'v4', auth: authClient });

  await sheets.spreadsheets.values.update({
    spreadsheetId,
    range,
    valueInputOption: 'USER_ENTERED',
    requestBody: { values: [[value]] }
  });

  console.log(`\n✅ Ячейка ${range} обновлена: ${value}`);
}

// CLI
const [,, command, ...args] = process.argv;

(async () => {
  try {
    switch (command) {
      case 'list':
        await listSheets();
        break;
      case 'read':
        await readSheet(args[0], args[1]);
        break;
      case 'append':
        await appendRow(args[0], args[1], args[2]);
        break;
      case 'create':
        await createSheet(args[0]);
        break;
      case 'update':
        await updateCell(args[0], args[1], args[2]);
        break;
      default:
        console.log(`
Google Sheets Manager

Команды:
  list                              - Список доступных таблиц
  read <id> [sheet]                 - Прочитать данные
  append <id> <sheet> <json>        - Добавить строку
  create <title>                    - Создать таблицу
  update <id> <range> <value>       - Обновить ячейку

Примеры:
  node scripts/sheets-manager.js list
  node scripts/sheets-manager.js read 1ABC123 "Лист1"
  node scripts/sheets-manager.js append 1ABC123 "Лист1" '{"name":"John","age":30}'
  node scripts/sheets-manager.js create "Новая таблица"
  node scripts/sheets-manager.js update 1ABC123 "A1" "Привет"
        `);
    }
  } catch (error) {
    console.error('Ошибка:', error.message);
  }
})();
