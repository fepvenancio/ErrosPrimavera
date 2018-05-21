EXEC STD_DropProcedure [EAP_ProcessaMapaAO_F2]
GO
/*
PROCESSAMENTO do Modelo de Abates de ANGOLA (AO)
   @Plano:		Identificador do Plano de Depreciação
   @Exercicio:  Identificador do Exercício Económico
   @MesInicio:	Identificador o Mês Inicial do Exercício
*/
CREATE PROCEDURE [dbo].[EAP_ProcessaMapaAO_F2]
	(
			@Plano				VARCHAR(25)
		,	@Exercicio			SMALLINT
		,	@MesInicio			SMALLINT
		,	@RestricaoFicha		NVARCHAR(MAX)
		,	@RestricaoClasse	NVARCHAR(MAX)
		,	@RestricaoFU		NVARCHAR(MAX)
		,	@RestricaoEstab		NVARCHAR(MAX)
		,	@RestricaoCC		NVARCHAR(MAX)
		,	@RestricaoTipoInv 	NVARCHAR(MAX)
		,	@RestricaoClassFisc	NVARCHAR(MAX)
		,	@RestricaoContaInv	NVARCHAR(MAX)
	)
AS
BEGIN
	
	/*Variáveis: Tipo UniqueIdentifier*/
	DECLARE @IdProcessamento		UNIQUEIDENTIFIER
	/*Variáveis: Tipo Texto*/
	DECLARE @Mapa					VARCHAR(25)
	DECLARE @Ficha					NVARCHAR(25)
	DECLARE @FAssociada				NVARCHAR(25)
	DECLARE @FichaGrupo				NVARCHAR(25)
	DECLARE @Justificacao			VARCHAR(25)
	/*Variáveis: Tipo Monetário*/
	DECLARE @AmAnterior				DECIMAL(28,10)
	DECLARE @AmExercicio			DECIMAL(28,10)
	DECLARE @AmAcumulada			DECIMAL(28,10)
	DECLARE @ValorActual			DECIMAL(28,10)
	DECLARE @AmCorrigida			DECIMAL(28,10)
	DECLARE @Reintegracao1			DECIMAL(28,10)
	DECLARE @ValorAquisicao			DECIMAL(28,10)
	DECLARE @DefeitoAcumulado		DECIMAL(28,10)
	DECLARE @ValorAbate				DECIMAL(28,10)
	/*Variáveis: Tipo Taxa*/
	DECLARE @TaxaPerdida			FLOAT
	DECLARE @TaxaAmortizacao		FLOAT
	/*Variáveis: Tipo Boolean*/
	DECLARE @Reparacao				BIT
	DECLARE @GrupoHomogeneo			BIT
	DECLARE @TotalmenteReintegrado	BIT
	/*Variáveis: Tipo Numérico*/
	DECLARE @Ordem					SMALLINT
	DECLARE @ExercicioUltProc		SMALLINT
	/*Variáveis: Tipo Data*/
	DECLARE @DataFinal				SMALLDATETIME
	DECLARE @DataInicial			SMALLDATETIME
	
	/*Variáveis SQL*/ 
	DECLARE @TSQL_SELECT			NVARCHAR(MAX)
	DECLARE @TSQL_FROM				NVARCHAR(MAX)
	DECLARE @TSQL_WHERE				NVARCHAR(MAX)
	
	/*Definição do Mapa*/
	SET @Mapa = 'AOMF2'
	
	/*Data Inicial do Exercício*/
	SET @DataInicial = CAST(LTRIM(@MesInicio) + '/' + LTRIM(1) + '/' + LTRIM(@Exercicio) AS SMALLDATETIME)
	/*Data Final do Exercício*/
	SET @DataFinal = DATEDIFF(DAY, 1, DATEADD(YEAR, 1, @DataInicial))
	
	/*Anula processamento do Modelo*/
	DELETE FROM MapasAmortizacao WHERE Plano = @Plano AND Exercicio = @Exercicio AND Mapa = @Mapa
	
	/*Query SQL: Processamento do Modelo*/
	SET @TSQL_SELECT = ''
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + 'SELECT '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		F.Ficha, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		F.FAssociada, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.ValorAquisicao, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		F.Justificacao, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		J.GrupoHomogeneo, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.Ordem, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.Exercicio, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.ValorActual, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		0, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.AmExercicioActual, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.AmAcumuladaActual, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.TaxaAmortizacao, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.DefeitoAcumulado, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.AmExercicioBase, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.AmExercicioCorrigida, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.IdProcessamento, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.TotalmenteReintegrado, '
	SET @TSQL_SELECT = @TSQL_SELECT + CHAR(13) + '		P.ValorAbate '
	
	/* FROM */
	SET @TSQL_FROM = ''
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + 'FROM			Fichas						F	(NOLOCK) '
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + 'INNER JOIN	FichasCriteriosDepreciacao	FCD	(NOLOCK)	ON	FCD.Ficha = F.Ficha AND FCD.Periodo = 13 AND FCD.Exercicio = ' + LTRIM(@Exercicio) + ' AND FCD.Plano = ''' + LTRIM(@Plano) + ''' '
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + 'INNER JOIN	Classificacoes					(NOLOCK)	ON	Classificacoes.IdClassificacao = FCD.IdClassificacao '
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + 'INNER JOIN	ClassificacoesFiscais			(NOLOCK)	ON	ClassificacoesFiscais.IdClassificacao = FCD.IdClassificacao '
		
	/* Último Processamento */
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + 'INNER JOIN	Processamentos				P	(NOLOCK)	ON	P.Ficha = FCD.Ficha AND P.Plano = ''' + @Plano + ''' '
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + '	AND P.Ordem = (SELECT MAX(Ordem) '
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + '				   FROM Processamentos			(NOLOCK) '
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + '	               WHERE Plano = P.Plano AND Ficha = P.Ficha AND Exercicio <= ' + LTRIM(@Exercicio) + ') '
	
	/* LEFT JOIN */
	SET @TSQL_FROM = @TSQL_FROM + CHAR(13) + 'LEFT JOIN		Justificacoes				J	(NOLOCK)	ON	J.Justificacao = F.Justificacao '
	
	/* Cláusula WHERE */
	SET @TSQL_WHERE = ''
	SET @TSQL_WHERE = @TSQL_WHERE + CHAR(13) + 'WHERE	F.Activo = 1 '
	SET @TSQL_WHERE = @TSQL_WHERE + CHAR(13) + '	AND	F.DataUtilizacao <= ''' + CONVERT(VARCHAR(10), @DataFinal, 121) + ''' '
	SET @TSQL_WHERE = @TSQL_WHERE + CHAR(13) + '	AND F.Ficha NOT IN (SELECT Ficha FROM dbo.[EAP_DaFichasDecompostasPeriodoPlano]( ''' + @Plano + ''', ' + LTRIM(@Exercicio) + ', 13, 31, 0 )) '

	/* Elementos Abatidos/Alienados no exercício */
	SET @TSQL_WHERE = @TSQL_WHERE + CHAR(13) + '	AND (P.Tipo = ''AB'' OR P.Tipo = ''AL'' OR P.Tipo = ''S'') '
	SET @TSQL_WHERE = @TSQL_WHERE + CHAR(13) + '	AND (P.Exercicio = ' + LTRIM(@Exercicio) + ') '
	
	/* Restrições */
	IF LEN(@RestricaoFicha) > 0
		SET @RestricaoFicha		= CHAR(13) + 'AND (' + REPLACE(@RestricaoFicha, 'Fichas.Ficha', 'F.Ficha') + ') '

	IF LEN(@RestricaoClasse) > 0
		SET @RestricaoClasse	= CHAR(13) + 'AND (' + REPLACE(@RestricaoClasse, 'Fichas.Classe', 'F.Classe') + ') '

	IF LEN(@RestricaoFU) > 0
		SET @RestricaoFU		= CHAR(13) + 'AND (F.Ficha IN (SELECT DISTINCT Bem FROM FichaFuncoes WHERE Exercicio = ' + LTRIM(@Exercicio) + ' AND ' + @RestricaoFU + ')) '

	IF LEN(@RestricaoEstab) > 0
		SET @RestricaoEstab		= CHAR(13) + 'AND (' + REPLACE(@RestricaoEstab, 'Fichas.Estabelecimento', 'F.Estabelecimento') + ') '

	IF LEN(@RestricaoCC) > 0
		SET @RestricaoCC		= CHAR(13) + 'AND (F.Ficha IN (SELECT DISTINCT Bem FROM FichaCCusto WHERE Exercicio = ' + LTRIM(@Exercicio) + ' AND ' + @RestricaoCC + ')) '

	IF LEN(@RestricaoTipoInv) > 0
		SET @RestricaoTipoInv	= CHAR(13) + 'AND (' + REPLACE(@RestricaoTipoInv, 'FichasCriteriosDepreciacao.Imobilizado', 'FCD.Imobilizado') + ') '

	IF LEN(@RestricaoClassFisc) > 0
		SET @RestricaoClassFisc	= CHAR(13) + 'AND (' + @RestricaoClassFisc + ') '

	IF LEN(@RestricaoContaInv) > 0
		SET @RestricaoContaInv	= CHAR(13) + 'AND (' + REPLACE(@RestricaoContaInv, 'FichasCriteriosDepreciacao.Conta', 'FCD.Conta') + ') '
	
	/* EXECUTE CURSOR */
	EXECUTE ('DECLARE ModeloF2 CURSOR FORWARD_ONLY FOR ' + 
	         @TSQL_SELECT + @TSQL_FROM + @TSQL_WHERE + 
	         @RestricaoFicha + @RestricaoClasse + @RestricaoFU + @RestricaoEstab + @RestricaoCC + 
	         @RestricaoTipoInv + @RestricaoClassFisc + @RestricaoContaInv)
	
	/*Processa Query SQL*/
	OPEN ModeloF2 FETCH NEXT FROM ModeloF2 INTO @Ficha
											, @FAssociada
											, @ValorAquisicao
											, @Justificacao
											, @GrupoHomogeneo
											, @Ordem
											, @ExercicioUltProc
											, @ValorActual
											, @AmAnterior
											, @AmExercicio
											, @AmAcumulada
											, @TaxaAmortizacao
											, @DefeitoAcumulado
											, @Reintegracao1
											, @AmCorrigida
											, @IdProcessamento
											, @TotalmenteReintegrado
											, @ValorAbate
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		SET @Reparacao				= 0
		SET @TaxaPerdida			= 0
		SET @FichaGrupo				= @Ficha
		
		IF (LEN(@FAssociada) > 0)	SET @Reparacao = 1
		IF (@Reparacao = 1)			SET @FichaGrupo = @FAssociada
		IF (@GrupoHomogeneo = 0)	SET @Justificacao = NULL
		
		SET @AmAnterior = @AmAcumulada - @AmExercicio - @AmCorrigida
		
		IF (@ValorActual > 0)
			SET @TaxaPerdida = ROUND((@DefeitoAcumulado / @ValorActual) * 100, 2)
		
		/*Não possui processamentos no Exercício*/
		IF @ExercicioUltProc <> @Exercicio
		BEGIN
			
			SET @AmExercicio = 0
			SET @Reintegracao1 = 0
			SET @TaxaAmortizacao = 0
			SET @AmAnterior = @AmAcumulada
			
		END
		/*Processamento no mesmo exercício*/
		ELSE 
		BEGIN
			
			SET @TotalmenteReintegrado = 0
			
		END
		
		/*Insere resultados do processamento na tabela*/
		INSERT INTO MapasAmortizacao 
			(	  IdLinha
				, Mapa
				, Plano
				, Exercicio
				, Ficha
				, FichaGrupo
				, ValorActivo1
				, ValorActivo4
				, AmAnterior
				, AmExercicio
				, AmAcumulada
				, TaxaAmortizacao
				, TaxaPerdida
				, Reintegracao1
				, AlienadoAbatido
				, Reparacao
				, Individual
				, IdProcessamento
				, TotalmenteReintegrado
				, Justificacao
				, ValorActivo2 )
		VALUES 
			(     NEWID()
				, @Mapa
				, @Plano
				, @Exercicio
				, @Ficha
				, @FichaGrupo
				, @ValorAquisicao
				, @ValorActual
				, @AmAnterior
				, @AmExercicio
				, @AmAcumulada
				, @TaxaAmortizacao
				, @TaxaPerdida
				, @Reintegracao1
				, 1
				, @Reparacao
				, 1
				, @IdProcessamento
				, @TotalmenteReintegrado
				, @Justificacao
				, @ValorAbate )
			
		/*Próximo registo*/
		FETCH NEXT FROM ModeloF2 INTO  @Ficha
									, @FAssociada
									, @ValorAquisicao
									, @Justificacao
									, @GrupoHomogeneo
									, @Ordem
									, @ExercicioUltProc
									, @ValorActual
									, @AmAnterior
									, @AmExercicio
									, @AmAcumulada
									, @TaxaAmortizacao
									, @DefeitoAcumulado
									, @Reintegracao1
									, @AmCorrigida
									, @IdProcessamento
									, @TotalmenteReintegrado
									, @ValorAbate
	END
	
	/*Query SQL: Actualiza o campo Justificação das fichas descendentes*/
	UPDATE MA 
	SET			Justificacao = MAP.Justificacao
	FROM		MapasAmortizacao MA
	INNER JOIN	MapasAmortizacao MAP	ON	MAP.Ficha		<> MA.Ficha 
										AND MAP.Ficha		= MA.FichaGrupo 
										AND MAP.Mapa		= MA.Mapa 
										AND MAP.Plano		= MA.Plano 
										AND MAP.Exercicio	= MA.Exercicio
	WHERE	MA.Plano		= @Plano 
	AND		MA.Exercicio	= @Exercicio 
	AND		MA.Mapa			= @Mapa
	
	/*Fecha e Remove Cursor*/
	CLOSE		ModeloF2
	DEALLOCATE	ModeloF2

END
GO