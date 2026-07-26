# GymFlow Flutter + Firebase

MVP de app para gimnasio con:

- Firebase Auth con email/password.
- Roles: entrenador y usuario.
- Cloud Firestore.
- Alta de clientes.
- Creación de rutinas.
- Ejercicios dentro de rutinas.
- Seguimiento de ejercicios completados.
- Datos guardados en Firebase.

## 1. Crear proyecto

```bash
flutter create gymflow
cd gymflow
```

Copia el contenido de este ZIP sobre el proyecto creado.

## 2. Instalar Firebase CLI y FlutterFire CLI

```bash
firebase login
dart pub global activate flutterfire_cli
```

## 3. Configurar Firebase

Desde la raíz del proyecto:

```bash
flutter pub get
flutterfire configure
```

Esto genera `lib/firebase_options.dart`.

## 4. Activar servicios en Firebase Console

En Firebase Console:

1. Authentication > Sign-in method > Email/Password > Enable.
2. Firestore Database > Create database.
3. Rules > pega el contenido de `firestore.rules`.

## 5. Ejecutar

```bash
flutter run
```

## Nota importante

Esta versión usa un `gymId` demo llamado `default_gym`. Sirve para probar rápido.
En una versión comercial se debería crear un gimnasio por entrenador y usar invitaciones/códigos para usuarios.
