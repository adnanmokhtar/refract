// A V1 whose only uniqueness guard is a pre-check against Supabase before the insert.
const { data: taken } = await supabase.from('profiles').select('id').eq('email', form.email.trim()).maybeSingle();
if (taken) { toast.error('This e-mail is already registered'); return; }
await supabase.from('marketers').insert({ name, email, phone });
