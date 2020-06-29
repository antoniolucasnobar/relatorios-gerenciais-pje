-- [R137782][MJ01]
-- EXPLAIN
WITH processos AS
(SELECT pp.id_processo_trf, pp.id_processo_parte
    FROM tb_pess_doc_identificacao pdi
    inner join tb_processo_parte pp
        on pdi.id_pessoa = pp.id_pessoa and pp.in_situacao = 'A'
    WHERE
        pdi.nr_documento_consulta  ilike
           regexp_replace(trim(COALESCE(:IDENTIFICACAO_SEM_MASCARA,'')), '[-\./]', '', 'g') || '%'
        and pdi.ds_nome_pessoa_consulta ilike '%' || TO_ASCII(COALESCE(:NOME_PARTE,'')) || '%'
        and not (COALESCE(:IDENTIFICACAO_SEM_MASCARA,'') = '' and COALESCE(:NOME_PARTE,'') = '')
)
select
    'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as "Detalhes"
    ,'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo
        AS "Processo"
    ,REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Unidade"
    ,to_char(ptrf.dt_autuacao::date, 'dd/mm/yyyy') as "Autuação"
    ,cj.ds_classe_judicial as "Classe Judicial"
    ,advogados.nomes as "Advogados"
    ,fase.nm_agrupamento_fase as "Fase"
    ,pt.nm_tarefa as "Tarefa"
from
    tb_processo p
    inner join tb_processo_trf ptrf on p.id_processo = ptrf.id_processo_trf
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    inner join tb_classe_judicial cj on ptrf.id_classe_judicial = cj.id_classe_judicial
    inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
    inner join tb_processo_tarefa pt on pt.id_processo_trf = ptrf.id_processo_trf
    INNER JOIN processos filtrados ON (p.id_processo = filtrados.id_processo_trf)
    LEFT JOIN LATERAL (
        SELECT string_agg(ul.ds_nome_consulta, ' / ') AS nomes
        FROM tb_usuario_login ul
            INNER JOIN tb_proc_parte_represntante rep ON ul.id_usuario = rep.id_representante
        WHERE rep.id_processo_parte = filtrados.id_processo_parte and rep.in_situacao = 'A'
    ) advogados ON TRUE
where
    CASE
       WHEN coalesce(:ID_FASE_PROCESSUAL, -1) = -1 THEN TRUE
       ELSE p.id_agrupamento_fase = :ID_FASE_PROCESSUAL
    END
    AND oj.id_orgao_julgador = COALESCE(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)

order by oj.nr_vara, p.nr_processo