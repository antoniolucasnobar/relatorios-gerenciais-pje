select x."Detalhes" as " ", x."Processo", x."Vara", to_char(x."Autuação", 'dd/mm/YYYY') as "Autuação", x."Classe Judicial", string_agg(x.ds_nome, ', ') as "Advogados",
	case x.id_agrupamento_fase
		when 1 then 'Elaboração'
		when 2 then 'Conhecimento'
		when 3 then 'Liquidação'
		when 4 then 'Execução'
		when 5 then 'Arquivo'
	end as "Fase",
	x.nm_tarefa as "Tarefa"
from
(select
	distinct p.nr_processo,
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as "Detalhes",
	'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo as "Processo",
	oj.ds_orgao_julgador as "Vara",
	ptrf.dt_autuacao as "Autuação",
	cj.ds_classe_judicial as "Classe Judicial",
	ul.ds_nome,
	p.id_agrupamento_fase,
	pt.nm_tarefa
from
	tb_processo p
	inner join tb_processo_trf ptrf on p.id_processo = ptrf.id_processo_trf
	inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
	inner join tb_classe_judicial cj on ptrf.id_classe_judicial = cj.id_classe_judicial
	inner join tb_processo_parte pp on p.id_processo = pp.id_processo_trf and pp.in_situacao = 'A'
	inner join tb_pess_doc_identificacao pdi on pp.id_pessoa = pdi.id_pessoa
	inner join tb_processo_tarefa pt on pt.id_processo_trf = ptrf.id_processo_trf
	left join tb_proc_parte_represntante rep on rep.id_processo_parte = pp.id_processo_parte and rep.in_situacao = 'A'
	left join tb_usuario_login ul on ul.id_usuario = rep.id_representante
where
	(replace(replace(replace(trim(pdi.nr_documento_identificacao),'.',''),'-',''), '/', '')  ilike replace(replace(replace(trim(COALESCE(:IDENTIFICACAO_SEM_MASCARA,'')),'.',''),'-',''), '/', '') || '%'
	and pdi.ds_nome_pessoa ilike '%' || COALESCE(:NOME_PARTE,'') || '%'
	)
	and exists (
		SELECT 1 FROM
		tb_processo_assunto pa
		inner join tb_assunto_trf a on a.id_assunto_trf = pa.id_assunto_trf
		WHERE pa.id_processo_trf = p.id_processo
		and a.ds_assunto_completo ilike '%' || COALESCE(:NOME_ASSUNTO,'') || '%'
	)
	and not (COALESCE(:IDENTIFICACAO_SEM_MASCARA,'') = '' and COALESCE(:NOME_PARTE,'') = '' and COALESCE(:NOME_ASSUNTO,'') = '')
) as x
group by x."Detalhes", x."Processo", x."Vara", x."Autuação", x."Classe Judicial", x.id_agrupamento_fase, x.nm_tarefa
order by 1