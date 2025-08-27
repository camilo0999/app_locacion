# 🚍 Proyecto

**Visualizador del trayecto del camion de la basura** es una aplicación móvil desarrollada con **Flutter** que permite **gestionar y visualizar rutas de vehículos en tiempo real**.
Los usuarios pueden rastrear los puntos de partida y llegada de un vehículo, con actualizaciones en vivo gracias a la integración con un **servidor backend robusto**.

---

## 👥 Integrantes del Grupo

* Brayan Riascos Murillo
* Jose Alejandro Velez
* Brayan Caicedo Angulo
* Juan Camilo Ibarguen Grueso

---

## 📌 Contextualización del Proyecto

El objetivo principal de esta aplicación es ofrecer una **solución eficiente para el seguimiento de rutas del camion de la basura**.

🔹 Los usuarios podrán:

* Visualizar información detallada de cada ruta.
* Consultar el **punto de partida** y el **punto final** en un mapa interactivo.
* Hacer un **seguimiento en vivo** de los vehículos.

La aplicación asegura que solo los **usuarios autorizados** tengan acceso a las rutas mediante un sistema de **autenticación segura**.

---

## 🛠️ Tecnologías y APIs Clave

### 📱 **Frontend** (Flutter)

* **Flutter**: Framework principal, una sola base de código para Android, iOS y Web.
* **go\_router**: Navegación declarativa y profunda.
* **flutter\_secure\_storage**: Almacenamiento seguro de credenciales y tokens.
* **Google Maps SDK**: Visualización de mapas, creación de marcadores (Markers) y polilíneas (Polylines).

🔑 **APIs de Google Cloud necesarias:**

* Maps JavaScript API *(para la versión web)*
* Maps SDK for Android *(para la versión Android)*
* Maps SDK for iOS *(para la versión iOS, si aplica)*

---

### 🌐 **Backend**

El servidor está desplegado en **Render** y disponible en:
👉 [https://server-location-1r1p.onrender.com](https://server-location-1r1p.onrender.com)

Funciones principales:

* **Peticiones HTTP** → Procesa solicitudes de autenticación y datos de rutas.
* **WebSockets (WS)** → Envía actualizaciones en tiempo real de la ubicación de los vehículos.

---

## 📷 Vista Previa de la App

*(Aquí puedes agregar capturas de pantalla o GIFs de la aplicación en acción, mostrando el mapa, el rastreo en tiempo real y la navegación entre pantallas)*

---

## 🚀 Futuras Mejoras

* Implementar notificaciones push para alertas de llegada y salida.
* Integrar estadísticas de recorridos y tiempos estimados.
* Optimizar la versión web para mayor compatibilidad.

---

✨ **Rastreador de Rutas**: haciendo el transporte más eficiente, seguro y conectado en tiempo real.

---
