const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

// Известные таблицы в проекте
const TABLES = [
  'candidates',
  'candidates_w',
  'pending_candidates',
  'approved_candidates',
  'rejected_candidates',
  'candidate_sessions',
  'candidate_responses',
  'interviews',
  'vacancies',
  'expenses',
  'users',
  'n8n_chat_histories',
  'sql_fixes'
];

async function listAllTables() {
  console.log('=== SUPABASE HR SYSTEM - ПРОВЕРКА ТАБЛИЦ ===\n');
  console.log('URL:', process.env.SUPABASE_URL);
  console.log('');

  for (const table of TABLES) {
    const { data, error, count } = await supabase
      .from(table)
      .select('*', { count: 'exact', head: true });

    if (error) {
      console.log(`❌ ${table}: ${error.message}`);
    } else {
      console.log(`✅ ${table}: ${count ?? 0} записей`);
    }
  }

  console.log('\n=== ПРИМЕРЫ ДАННЫХ ===\n');

  // Показать примеры из нескольких таблиц
  const samplesToShow = ['vacancies', 'candidates', 'interviews'];

  for (const table of samplesToShow) {
    const { data, error } = await supabase.from(table).select('*').limit(2);
    if (!error && data && data.length > 0) {
      console.log(`--- ${table} (первые 2 записи) ---`);
      console.log(JSON.stringify(data, null, 2));
      console.log('');
    }
  }
}

listAllTables().catch(console.error);
