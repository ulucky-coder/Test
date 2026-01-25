const { google } = require('googleapis');
const path = require('path');

const CREDENTIALS_PATH = path.join(__dirname, '..', 'credentials', 'google-credentials.json');

async function listGoogleSheets() {
  console.log('=== СПИСОК GOOGLE SHEETS ===\n');

  try {
    const auth = new google.auth.GoogleAuth({
      keyFile: CREDENTIALS_PATH,
      scopes: [
        'https://www.googleapis.com/auth/spreadsheets.readonly',
        'https://www.googleapis.com/auth/drive.readonly'
      ]
    });

    const authClient = await auth.getClient();
    const drive = google.drive({ version: 'v3', auth: authClient });

    // Получаем список всех Google Sheets
    const res = await drive.files.list({
      q: "mimeType='application/vnd.google-apps.spreadsheet'",
      fields: 'files(id, name, createdTime, modifiedTime, webViewLink)',
      orderBy: 'modifiedTime desc',
      pageSize: 50
    });

    const files = res.data.files;

    if (!files || files.length === 0) {
      console.log('Таблицы не найдены.');
      console.log('\nВозможные причины:');
      console.log('1. Service Account не имеет доступа ни к одной таблице');
      console.log('2. Нужно расшарить таблицы на: claude-sheets-bot@tes-2-n8n.iam.gserviceaccount.com');
      return;
    }

    console.log(`Найдено таблиц: ${files.length}\n`);
    console.log('─'.repeat(80));

    files.forEach((file, index) => {
      console.log(`\n${index + 1}. ${file.name}`);
      console.log(`   ID: ${file.id}`);
      console.log(`   Изменён: ${new Date(file.modifiedTime).toLocaleString('ru-RU')}`);
      console.log(`   URL: ${file.webViewLink}`);
    });

    console.log('\n' + '─'.repeat(80));
    console.log('\nЧтобы работать с таблицей, используй её ID в MCP инструментах.');

  } catch (error) {
    console.error('Ошибка:', error.message);

    if (error.message.includes('invalid_grant')) {
      console.log('\nПроверь что credentials файл валидный');
    }

    if (error.message.includes('Not Found')) {
      console.log('\nУстанови googleapis: npm install googleapis');
    }
  }
}

listGoogleSheets();
