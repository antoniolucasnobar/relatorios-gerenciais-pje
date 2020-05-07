-- R136874 - Relatório SAO -  EMBARGOS DECLARATÓRIOS PENDENTES
-- REGRAS:
-- Ter um concluso para:
--  Conclusos os autos para julgamento dos Embargos de Declaração a nome do Juiz
--
-- Tem algo semelhante nesse????? Antes do concluso, ter um documento do tipo:
--  - Embargos a Execucao
--  - Impugnacao a Sentenca de Liquidacao
--
-- Estar em qq fase
-- 
-- NÃO Existir um movimento dentre os seguintes, após o concluso
-- 50086 - Encerrada a conclusão
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
-- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}  
--


WITH tipos_documento AS (
    --16	Embargos à Execução	S			7143
    --32	Impugnação à Sentença de Liquidação	S			53
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento IN ('53', '7143') 
        and in_ativo = 'S'
),
movimentos_pendente_embargos_declaratorio AS (
    SELECT ev.id_evento_processual 
    FROM tb_evento_processual ev 
    WHERE 
-- NÃO Existir um movimento dentre os seguintes, após o concluso
-- 50086 - Encerrada a conclusão
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
-- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}  
        ev.cd_evento IN 
        ('50086', '198', '871', '200', '235', '230')
)  ,
pendentes_embargos_declaratorio AS (
SELECT  concluso.id_pessoa_magistrado, 
        pen.id_processo_evento,
        pen.dt_atualizacao AS pendente_desde,
        p.id_processo,
        p.nr_processo
    FROM 
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pen 
        ON (pen.id_processo_evento = concluso.id_processo_evento 
            AND pen.id_processo_evento_excludente IS NULL
            -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
            and pen.id_evento = 51 
            -- Conclusão do tipo "Julgamento dos Embargos de Declara__o" 
            AND 
                pen.ds_texto_final_interno ilike 
                    'Conclusos os autos para julgamento dos Embargos de Declara__o%'
        )
    INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
    INNER JOIN LATERAL (
        SELECT doc.dt_juntada FROM tb_processo_documento doc WHERE 
        doc.id_processo = pen.id_processo
        AND doc.dt_juntada < pen.dt_atualizacao
        AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipos_documento)
        ORDER BY doc.dt_juntada DESC LIMIT 1
    ) peticao ON TRUE -- //TODO: vai precisar de peticao? qual tipo
    WHERE
        concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe 
            WHERE pen.id_processo = pe.id_processo
                AND pe.id_processo_evento_excludente IS NULL
                AND pe.dt_atualizacao > pen.dt_atualizacao
                AND pe.id_evento IN (
                    SELECT id_evento_processual FROM movimentos_pendente_embargos_declaratorio
                )
        )
)
SELECT ul.ds_nome AS "Magistrado", 
conclusos_por_magistrado.pendentes_embargo AS "Pendentes",
'$URL/execucao/T959?MAGISTRADO='||conclusos_por_magistrado.id_pessoa_magistrado||'&texto='||conclusos_por_magistrado.pendentes_embargo as "Ver Pendentes"
FROM  (
    SELECT  pendentes_embargos_declaratorio.id_pessoa_magistrado, 
            COUNT(pendentes_embargos_declaratorio.id_pessoa_magistrado) AS pendentes_embargo
    FROM pendentes_embargos_declaratorio
    GROUP BY pendentes_embargos_declaratorio.id_pessoa_magistrado
) conclusos_por_magistrado  
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = conclusos_por_magistrado.id_pessoa_magistrado)
ORDER BY ul.ds_nome
