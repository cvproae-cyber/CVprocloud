# المرحلة الأولى: بناء الواجهة الأمامية (Frontend)
FROM node:20-slim AS frontend-builder

# تعريف المتغيرات المطلوبة للبناء
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ARG VITE_PROXY_HEADER

# تحويل الـ ARGs إلى ENV لكي يراها Vite أثناء الـ Build
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY
ENV VITE_PROXY_HEADER=$VITE_PROXY_HEADER

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./

# Vite سيقوم تلقائياً بالبحث عن المتغيرات التي تبدأ بـ VITE_ في بيئة النظام
RUN npm run build

# المرحلة الثانية: تجهيز الخادم (Backend)
FROM node:20-slim
WORKDIR /app

# نسخ ملفات الخادم وتثبيت المكتبات
COPY backend/package*.json ./backend/
WORKDIR /app/backend
RUN npm install --production
COPY backend/ ./

# جلب ملفات الواجهة الأمامية التي تم بناؤها في المرحلة الأولى
# ووضعها داخل مجلد public في الخادم ليتم عرضها للمستخدم
COPY --from=frontend-builder /app/frontend/dist ./public

# إعدادات البيئة
ENV NODE_ENV=production
ENV PORT=8080

# فتح المنفذ 8080 (الافتراضي لـ Cloud Run)
EXPOSE 8080

# أمر تشغيل الخادم
CMD ["node", "server.js"]