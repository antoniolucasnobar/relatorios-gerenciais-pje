-- R136875 - EMBARGOS DECLARATÓRIOS JULGADOS
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
WITH
tipo_documento_sentenca AS (
    --62	Sentença	S			7007
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento = '7007' 
        and in_ativo = 'S'
),
movimentos_embargos_declaracao_julgados AS (
    SELECT ev.id_evento_processual 
    FROM tb_evento_processual ev 
    WHERE 
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
        ev.cd_evento IN 
        ('198', '871', '200', '235')
) 
,
embargos_declaracao_julgados AS (
    select 
    assin.id_pessoa, 
    doc.dt_juntada,
    doc.id_processo
    from tb_processo_documento doc 
    inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    inner join lateral (
        select pen.ds_texto_final_interno FROM 
        tb_conclusao_magistrado concluso
        INNER JOIN tb_processo_evento pen 
            ON (pen.id_processo_evento = concluso.id_processo_evento 
                and pen.id_processo = doc.id_processo 
                AND pen.id_processo_evento_excludente IS NULL
                and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                -- AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
            )
        where pen.dt_atualizacao < doc.dt_juntada 
        order by pen.dt_atualizacao desc 
        limit 1
    ) concluso on TRUE
    where doc.in_ativo = 'S'
    AND doc.id_tipo_processo_documento = (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    and doc.dt_juntada :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
    and concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento dos Embargos de Declara__o%'
    AND EXISTS (
        SELECT 1 FROM 
            tb_processo_evento pen 
        WHERE 
            pen.id_processo = doc.id_processo 
            AND pen.id_processo_evento_excludente IS NULL
            and pen.id_evento IN (
                SELECT id_evento_processual FROM movimentos_embargos_declaracao_julgados
            )
            AND date(doc.dt_juntada) <= date(pen.dt_atualizacao)
            -- AND  pen.ds_texto_final_interno ilike '%Embargos de Declara__o%' 
    )
)
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
         'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
         ||cj.ds_classe_judicial_sigla||' '
         ||p.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
    ul.ds_nome AS "Magistrado",
    embargos_declaracao_julgados.dt_juntada AS "Julgado em"
FROM embargos_declaracao_julgados 
    INNER JOIN tb_usuario_login ul on (ul.id_usuario = embargos_declaracao_julgados.id_pessoa)
    INNER JOIN tb_processo p ON (p.id_processo = embargos_declaracao_julgados.id_processo)
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
ORDER BY ul.ds_nome, embargos_declaracao_julgados.dt_juntada
