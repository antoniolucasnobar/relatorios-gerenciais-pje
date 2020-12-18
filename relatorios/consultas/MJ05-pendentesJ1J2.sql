-- [MJ05][R145332] Pendentes J1 e J2
select 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as "Detalhes",
p.nr_processo, ojc.ds_cargo as cargo, pt.nm_tarefa as tarefa, pt.dh_criacao_tarefa as "tarefa desde"
 from tb_processo_trf ptrf
    inner join tb_processo p on p.id_processo = ptrf.id_processo_trf
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    inner join tb_orgao_julgador_cargo ojc using (id_orgao_julgador_cargo)
 where dt_autuacao between to_timestamp(:DATA_INICIAL, 'yyyy-MM-dd' ) and (to_timestamp(:DATA_FINAL, 'yyyy-MM-dd' ) + interval '24 hours')
    and ((:ORGAO_JULGADOR is null) or (ptrf.id_orgao_julgador = :ORGAO_JULGADOR))
    and ((:CARGO is null) or (position(:CARGO in ojc.ds_cargo) > 0))
    and p.id_agrupamento_fase = 2
    and not exists (select pr.id_processo_trf from tb_proc_trf_redistribuicao pr where pr.id_processo_trf = ptrf.id_processo_trf)
    and not exists (select 1 from tb_resultado_sentenca rs where rs.id_processo_trf = p.id_processo and rs.in_homologado = true)
    and not exists (select 1 from tb_processo_evento pe where pe.id_processo = p.id_processo AND pe.id_evento = 466)
