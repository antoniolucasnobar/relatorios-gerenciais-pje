  SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj.ds_classe_judicial_sigla||' '||p.nr_processo as "Processo",
    (SELECT REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' )
        FROM tb_orgao_julgador oj
        WHERE oj.id_orgao_julgador = ptrf.id_orgao_julgador) as "Unidade",
    pe.dt_atualizacao as "Data",
    ul.ds_nome as "Parte",
    case pp.in_participacao
        when 'A' then 'Ativo'
        when 'P' then 'Passivo'
    end as "Polo",
    pp.nr_ordem as "Ordem",
    fase.nm_agrupamento_fase as "Fase",
    pt.nm_tarefa as "Tarefa"
from tb_processo_evento pe 
    inner join tb_processo p on p.id_processo = pe.id_processo
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo   
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    inner join tb_processo_parte pp on pp.id_processo_trf = p.id_processo
    inner join tb_usuario_login ul on ul.id_usuario = pp.id_pessoa
    inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
    INNER JOIN pje.tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
where pe.id_evento = 11382 
    and pe.dt_atualizacao:: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
    and ptrf.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, ptrf.id_orgao_julgador)
    and p.id_agrupamento_fase in (2,3,4)
    and pp.in_situacao = 'A'
    and pp.in_participacao in ('A','P')
    and pp.in_parte_principal = 'S'    
    AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
order by pe.dt_atualizacao, pp.in_participacao, pp.nr_ordem
