const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function listAllTables() {
  console.log('=== ПОИСК ТАБЛИЦ В SUPABASE ===\n');

  // Способ 1: Через REST API endpoint напрямую
  console.log('Запрашиваю OpenAPI schema...\n');

  try {
    const response = await fetch(process.env.SUPABASE_URL + '/rest/v1/', {
      headers: {
        'apikey': process.env.SUPABASE_ANON_KEY,
        'Authorization': 'Bearer ' + process.env.SUPABASE_ANON_KEY
      }
    });

    if (response.ok) {
      const schema = await response.json();
      console.log('Доступные endpoints (таблицы):', Object.keys(schema.paths || {}).filter(p => p !== '/'));
    }
  } catch (e) {
    console.log('OpenAPI недоступен:', e.message);
  }

  // Способ 2: Пробуем RPC функцию для списка таблиц (если есть)
  console.log('\nПробую получить таблицы через information_schema...');

  const { data: rpcData, error: rpcError } = await supabase.rpc('get_tables');
  if (!rpcError && rpcData) {
    console.log('Таблицы (через RPC):', rpcData);
  }

  // Способ 3: Прямой запрос к PostgREST для получения определений
  console.log('\nЗапрашиваю PostgREST schema definition...');

  try {
    const defResponse = await fetch(process.env.SUPABASE_URL + '/rest/v1/', {
      method: 'OPTIONS',
      headers: {
        'apikey': process.env.SUPABASE_ANON_KEY
      }
    });

    // PostgREST возвращает OpenAPI spec
    const openApiResponse = await fetch(process.env.SUPABASE_URL + '/rest/v1/', {
      headers: {
        'apikey': process.env.SUPABASE_ANON_KEY,
        'Accept': 'application/openapi+json'
      }
    });

    if (openApiResponse.ok) {
      const openApi = await openApiResponse.json();
      if (openApi.paths) {
        const tables = Object.keys(openApi.paths)
          .filter(p => p.startsWith('/') && p !== '/')
          .map(p => p.replace('/', ''));
        console.log('\nНайденные таблицы:');
        tables.forEach(t => console.log('  - ' + t));
      }

      if (openApi.definitions) {
        console.log('\nСхемы (definitions):');
        Object.keys(openApi.definitions).forEach(d => console.log('  - ' + d));
      }
    }
  } catch (e) {
    console.log('Ошибка:', e.message);
  }
}

listAllTables().catch(console.error);
