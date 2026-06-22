// =============================================
// SUPABASE CONFIG — Plataforma Método 3Ps
// =============================================
// Chave pública/publishable usada no navegador.
// Nunca coloque service_role key neste arquivo.

const SUPABASE_URL = 'https://pqhmmgskgcmbzrygeynp.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_rPK909lZax0-OjogQ1claA_kBMv6ruy';

window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
