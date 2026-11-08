module.exports = [
  {
    id: 'automatico',
    name: 'Automatico (auto-seleccion)',
    provider: 'nvidia',
    baseUrl: 'https://integrate.api.nvidia.com/v1',
    model: 'google/gemma-4-31b-it',
    apiKey: 'TU_API_KEY_AQUI',

    auto: true,
    available: true,
    system: 'Eres un asistente de IA. Responde en espanol a menos que se pida otro idioma.'
  }
];
