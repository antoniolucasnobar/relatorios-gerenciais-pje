:ID_ETIQUETA
Chip (etiqueta)
retorno NUMERO
tipo COMBOBOX

select null, 'TODOS'
			union all
			(select id_etq_etiqueta, nm_etiqueta from tb_etq_etiqueta order by nm_etiqueta)


-- Aguardando Prazo
-- Mandado pendente
-- Petição Não Apreciada
-- Laudo pendente
--
-- Arquivado Definitivamente
-- CCLE
-- Arquivado Provisoriamente
-- 	string_agg(eq.nm_etiqueta, ' , ') AS "Chip (etiqueta)",
