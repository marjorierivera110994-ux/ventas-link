/* Ventas Link — datos PÚBLICOS para conectarse a la base.
   Esta llave está hecha para ir en el navegador ("publishable"): con ella nadie puede leer datos ajenos,
   porque cada tabla tiene sus permisos. La llave SECRETA jamás va aquí ni en ningún archivo que vea el navegador. */
window.VL_CONFIG = {
  url: 'https://vqhkbijlnpjtklnlvvuf.supabase.co',
  llave: 'sb_publishable_z8mJR0gMI1U50BdKzliL6A_Q4FBOukQ',
  /* ¿El correo de acceso trae un código para escribir? Hoy NO: Supabase envía su correo fijo (en inglés, solo con un botón)
     y no deja cambiarlo hasta conectar un servicio de correo propio. Cuando se cambie la plantilla (supabase/correos), poner true. */
  correoConCodigo: false
};
