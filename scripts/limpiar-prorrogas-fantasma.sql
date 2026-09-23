-- ============================================================
-- limpiar-prorrogas-fantasma.sql
-- Elimina las prórrogas creadas por el bug (activas, vacías).
-- IMPORTANTE: hacer BACKUP de inmobiliaria.db antes de correr:
--   copy inmobiliaria.db inmobiliaria.db.bak
-- Correr con la app CERRADA en ambas PCs:
--   sqlite3 inmobiliaria.db < limpiar-prorrogas-fantasma.sql
-- ============================================================

-- 1. Ver cuáles se van a borrar (revisar antes de continuar):
-- SELECT id, contrato_id, cuotas_total, monto_base, fecha_inicio, activa
-- FROM prorrogas
-- WHERE cuotas_total = 0 AND monto_base = 0
--   AND (fecha_inicio IS NULL OR fecha_inicio = '');

-- 2. Borrar períodos huérfanos de esas prórrogas:
DELETE FROM prorroga_periodos
WHERE prorroga_id IN (
  SELECT id FROM prorrogas
  WHERE cuotas_total = 0 AND monto_base = 0
    AND (fecha_inicio IS NULL OR fecha_inicio = '')
);

-- 3. Borrar las prórrogas fantasma:
DELETE FROM prorrogas
WHERE cuotas_total = 0 AND monto_base = 0
  AND (fecha_inicio IS NULL OR fecha_inicio = '');
