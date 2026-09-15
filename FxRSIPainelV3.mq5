//+------------------------------------------------------------------+
//|                                Grid Trader Compras v3.92.mq5     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Grid Trader Compras"
#property version   "3.92"
#property description "Painel Minimalista Sem Grade + Grid Perpétuo + Gatilho RSI 14 + Stop $200"

#include <Trade\Trade.mqh>

// Parâmetros de Entrada
input group "=== Estratégia de Compra (Grid) ==="
input double   Lote_Compra = 0.03;                   // Lote base para ordens de compra
input int      Distancia_Grid_Compra = 1000;         // Distância entre compras (pontos)
input int      Take_Profit_Compra = 1000;            // Take Profit compras (pontos)

input group "=== Lote Progressivo (Compra) ==="
input bool     Usar_Lote_Progressivo = true;         // Ativar incremento de lote
input int      Ordens_Para_Incrementar = 10;         // A cada quantas compras ATIVAS incrementa
input double   Incremento_Lote_Compra = 0.01;        // Quanto incrementa por nível

input group "=== Filtro RSI Inicial (Apenas 1ª Vez) ==="
input bool               Usar_Filtro_RSI = true;             // Ativar filtro de RSI para o gatilho inicial
input int                RSI_Periodo = 14;                   // Período do RSI
input ENUM_TIMEFRAMES    RSI_Timeframe = PERIOD_CURRENT;     // Timeframe do RSI
input ENUM_APPLIED_PRICE RSI_Preco = PRICE_CLOSE;            // Preço aplicado ao RSI
input double             RSI_Nivel_Sobrecompra = 70.0;       // Nível de sobrecompra (Visual)
input double             RSI_Nivel_Sobrevenda = 30.0;        // Nível de sobrevenda (Gatilho Inicial)

input group "=== Filtro Média Móvel (Tendência) ==="
input bool               Usar_Filtro_MA200 = false;          // (Desativado) Só compra se preço estiver ACIMA da média
input int                MA_Periodo = 200;                   // Período da média móvel
input ENUM_MA_METHOD     MA_Metodo = MODE_SMA;               // Método da média
input ENUM_APPLIED_PRICE MA_Preco = PRICE_CLOSE;             // Preço aplicado à média
input ENUM_TIMEFRAMES    MA_Timeframe = PERIOD_CURRENT;      // Timeframe da média
input int                Distancia_Banda_MA = 2330;          // Distância das bandas (pontos)
input color              Cor_Banda_Superior = C'255,152,0';  // Cor da banda superior
input color              Cor_Banda_Inferior = C'0,188,212';  // Cor da banda inferior

input group "=== Stop Financeiro da Sessão ==="
input bool   Usar_Stop_Financeiro = true;            // Ativar proteções financeiras da sessão
input double Meta_Lucro_Sessao = 400.0;              // Meta de lucro da sessão em USD (Stop Gain)
input double Stop_Loss_Sessao = 200.0;               // Perda máxima da sessão em USD (Stop Loss de $200)

input group "=== Configurações do Painel ==="
input int      Magic_Number = 123456;                // Número mágico do EA
input int      Painel_X = 15;                        // Posição X do painel
input int      Painel_Y = 25;                        // Posição Y do painel
input bool     Mostrar_Botao_Reset = true;           // Mostrar botão de reset manual
input color    Cor_Fundo = clrBlack;                   // Fundo preto do painel
input color    Cor_Card = clrBlack;                    // Mantido para compatibilidade
input color    Cor_Header = C'212,175,55';             // Dourado
input color    Cor_Positivo = C'46,204,113';         // Cor lucro (Verde suave)
input color    Cor_Negativo = C'231,76,60';          // Cor prejuízo (Vermelho suave)
input color    Cor_Alerta = C'241,196,15';           // Cor alerta (Amarelo)
input color    Cor_Texto = C'212,175,55';               // Dourado
input color    Cor_Texto_Sec = C'212,175,55';           // Dourado
input color    Cor_Botao = C'215,58,73';             // Cor do botão reset

// Variáveis Globais
CTrade trade;
bool grid_ja_ativado = false; 

// Controle de Sessão
double capital_inicial_sessao = 0;
double balance_inicial = 0;
datetime hora_inicio_sessao = 0;
int contador_resets = 0;

// Indicadores
int rsi_handle = INVALID_HANDLE;
double rsi_atual = 50.0;

int ma_handle = INVALID_HANDLE;
double ma_atual = 0.0;

// Layout do painel
int PAINEL_LARGURA = 1080;
int PAINEL_ALTURA  = 0;

// Declaração de funções
bool ExisteCompraProxima(double preco, int distancia_minima);
bool AbrirOrdemCompra(double preco);
int ContarOrdens(ENUM_POSITION_TYPE tipo);
double CalcularLucroEA();
double CalcularHistoricoSessao();
double CalcularLoteAtual();
bool VerificarStopSessao();

void CriarObjetoPainel(string nome, int x, int y, int largura, int altura, color cor, int corner = CORNER_LEFT_UPPER);
void CriarTexto(string nome, int x, int y, string texto, color cor, int tamanho, string fonte = "Arial", int corner = CORNER_LEFT_UPPER);
void CriarBotao(string nome, int x, int y, int largura, int altura, string texto, color cor_fundo, color cor_texto);
void CriarSecao(string nome_base, int x, int y, string titulo);
void DeletarTodosObjetos();
void ResetarEstrategia();
void FecharTodasPosicoes();
void CriarPainelModerno();
void AtualizarPainelModerno();
bool AtualizarIndicadores();
bool RSIPermiteCompra();
bool MAPermiteCompra();
void DesenharBandasMA();
void DesenharNiveisGrid();
void CriarLinhaHorizontal(string nome, double preco, color cor);
void AdicionarIndicadoresNoGrafico();

//+------------------------------------------------------------------+
//| Função de Inicialização                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(10);
   
   ENUM_SYMBOL_TRADE_EXECUTION exe_mode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
   if(exe_mode == SYMBOL_TRADE_EXECUTION_EXCHANGE || exe_mode == SYMBOL_TRADE_EXECUTION_INSTANT)
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
   else
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   balance_inicial = AccountInfoDouble(ACCOUNT_BALANCE);
   capital_inicial_sessao = AccountInfoDouble(ACCOUNT_EQUITY);
   hora_inicio_sessao = TimeCurrent();
   
   rsi_handle = iRSI(_Symbol, RSI_Timeframe, RSI_Periodo, RSI_Preco);
   ma_handle  = iMA(_Symbol, MA_Timeframe, MA_Periodo, 0, MA_Metodo, MA_Preco);
   
   if(rsi_handle == INVALID_HANDLE || ma_handle == INVALID_HANDLE)
   {
      Print("❌ ERRO: Falha ao criar os indicadores.");
      return(INIT_FAILED);
   }
   
   PAINEL_ALTURA = Mostrar_Botao_Reset ? 96 : 70;
   
   AdicionarIndicadoresNoGrafico();
   CriarPainelModerno();
   AtualizarIndicadores();
   DesenharBandasMA();
   DesenharNiveisGrid();
   
   Print("▶️ Grid Trader Compras v3.92 (Painel Minimalista Sem Grade) Iniciado!");
   return(INIT_SUCCEEDED);
}

void AdicionarIndicadoresNoGrafico()
{
   bool has_ma = false;
   int inds_main = ChartIndicatorsTotal(0, 0);
   for(int j = 0; j < inds_main; j++) {
      if(StringFind(ChartIndicatorName(0, 0, j), "MA") >= 0) { has_ma = true; break; }
   }
   if(!has_ma) ChartIndicatorAdd(0, 0, ma_handle);

   int sub_windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   bool has_rsi = false;
   for(int i = 1; i < sub_windows; i++) {
      int inds = ChartIndicatorsTotal(0, i);
      for(int j = 0; j < inds; j++) {
         if(StringFind(ChartIndicatorName(0, i, j), "RSI") >= 0) { has_rsi = true; break; }
      }
   }
   if(!has_rsi) ChartIndicatorAdd(0, sub_windows, rsi_handle);
}

void OnDeinit(const int reason)
{
   if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
   if(ma_handle  != INVALID_HANDLE) IndicatorRelease(ma_handle);
   DeletarTodosObjetos();
}

void OnTick()
{
   AtualizarIndicadores();
   DesenharBandasMA();
   DesenharNiveisGrid();
   AtualizarPainelModerno();

   if(VerificarStopSessao()) return;

   ExecutarEstrategiaCompra();
}

bool AtualizarIndicadores()
{
   if(rsi_handle == INVALID_HANDLE || ma_handle == INVALID_HANDLE) return false;
   double buffer_rsi[1], buffer_ma[1];
   if(CopyBuffer(rsi_handle, 0, 0, 1, buffer_rsi) < 1) return false;
   if(CopyBuffer(ma_handle, 0, 0, 1, buffer_ma) < 1) return false;
   rsi_atual = buffer_rsi[0];
   ma_atual  = buffer_ma[0];
   return true;
}

void DesenharBandasMA()
{
   if(ma_handle == INVALID_HANDLE) return;
   CriarLinhaHorizontal("linha_ma200", ma_atual, Cor_Negativo);
   if(!Usar_Filtro_MA200) {
      ObjectDelete(0, "linha_banda_superior");
      ObjectDelete(0, "linha_banda_inferior");
      return;
   }
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   CriarLinhaHorizontal("linha_banda_superior", ma_atual + (Distancia_Banda_MA * point), Cor_Header);
   CriarLinhaHorizontal("linha_banda_inferior", ma_atual - (Distancia_Banda_MA * point), Cor_Header);
}

void DesenharNiveisGrid()
{
   for(int n = 0; n < 100; n++) ObjectDelete(0, "linha_grid_" + IntegerToString(n));
   int nivel = 0;
   for(int i = PositionsTotal() - 1; i >= 0 && nivel < 100; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      string nome = "linha_grid_" + IntegerToString(nivel);
      CriarLinhaHorizontal(nome, PositionGetDouble(POSITION_PRICE_OPEN), Cor_Header);
      ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, nome, OBJPROP_WIDTH, 1);
      nivel++;
   }
}

void CriarLinhaHorizontal(string nome, double preco, color cor)
{
   if(ObjectFind(0, nome) < 0) {
      ObjectCreate(0, nome, OBJ_HLINE, 0, 0, preco);
      ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, nome, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, nome, OBJPROP_BACK, true);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
   } else {
      ObjectSetDouble(0, nome, OBJPROP_PRICE, preco);
   }
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
}

bool RSIPermiteCompra()
{
   if(!Usar_Filtro_RSI) return true;
   return (rsi_atual < RSI_Nivel_Sobrevenda);
}

bool MAPermiteCompra()
{
   if(!Usar_Filtro_MA200) return true;
   double preco_atual = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (preco_atual > ma_atual);
}

bool VerificarStopSessao()
{
   if(!Usar_Stop_Financeiro) return false;
   double equity_atual = AccountInfoDouble(ACCOUNT_EQUITY);
   double resultado_sessao = equity_atual - capital_inicial_sessao;

   if(Meta_Lucro_Sessao > 0 && resultado_sessao >= Meta_Lucro_Sessao)
   {
      Print("🎯 META DE LUCRO ATINGIDA: $", DoubleToString(resultado_sessao, 2));
      contador_resets++;
      ResetarEstrategia();
      return true;
   }

   if(Stop_Loss_Sessao > 0 && resultado_sessao <= -MathAbs(Stop_Loss_Sessao))
   {
      Print("🛑 STOP LOSS DE $200 ATINGIDO: $", DoubleToString(resultado_sessao, 2));
      contador_resets++;
      ResetarEstrategia();
      return true;
   }
   return false;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "btn_reset")
   {
      int resposta = MessageBox("Deseja RESETAR MANUALMENTE a estratégia?", "Confirmar", MB_YESNO | MB_ICONWARNING);
      if(resposta == IDYES) {
         contador_resets++;
         ResetarEstrategia();
      }
      ObjectSetInteger(0, "btn_reset", OBJPROP_STATE, false);
      ChartRedraw();
   }
}

void ExecutarEstrategiaCompra()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int ordens_compradas = ContarOrdens(POSITION_TYPE_BUY);

   if(!grid_ja_ativado)
   {
      if(ordens_compradas == 0)
      {
         if(!RSIPermiteCompra() || !MAPermiteCompra()) return;
         if(AbrirOrdemCompra(ask)) grid_ja_ativado = true;
      }
      return;
   }
   
   if(ordens_compradas == 0)
   {
      AbrirOrdemCompra(ask);
      return;
   }
   
   if(ExisteCompraProxima(ask, Distancia_Grid_Compra)) return;
   
   double menor_distancia = 999999;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      
      double preco_ordem = PositionGetDouble(POSITION_PRICE_OPEN);
      double distancia = MathAbs((ask - preco_ordem) / point);
      if(distancia < menor_distancia) menor_distancia = distancia;
   }
   
   if(menor_distancia >= Distancia_Grid_Compra) AbrirOrdemCompra(ask);
}

bool ExisteCompraProxima(double preco, int distancia_minima)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      
      double preco_ordem = PositionGetDouble(POSITION_PRICE_OPEN);
      double distancia = MathAbs((preco - preco_ordem) / point);
      if(distancia < distancia_minima * 0.5) return true;
   }
   return false;
}

double CalcularLoteAtual()
{
   double lote = Lote_Compra;
   if(Usar_Lote_Progressivo && Ordens_Para_Incrementar > 0)
   {
      int compras_ativas = ContarOrdens(POSITION_TYPE_BUY);
      int nivel = compras_ativas / Ordens_Para_Incrementar;
      lote = Lote_Compra + (nivel * Incremento_Lote_Compra);
   }
   double lote_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lote_max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lote_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lote_step > 0) lote = MathRound(lote / lote_step) * lote_step;
   lote = NormalizeDouble(lote, 2);
   if(lote < lote_min) lote = lote_min;
   if(lote > lote_max) lote = lote_max;
   return lote;
}

bool AbrirOrdemCompra(double preco)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tp = preco + (Take_Profit_Compra * point);
   tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   double lote_atual = CalcularLoteAtual();
   return trade.Buy(lote_atual, _Symbol, 0, 0, tp, "Grid Buy L" + DoubleToString(lote_atual, 2));
}

void FecharTodasPosicoes()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         trade.PositionClose(ticket);
   }
}

void ResetarEstrategia()
{
   FecharTodasPosicoes();
   grid_ja_ativado = false;
   balance_inicial = AccountInfoDouble(ACCOUNT_BALANCE);
   capital_inicial_sessao = AccountInfoDouble(ACCOUNT_EQUITY);
   hora_inicio_sessao = TimeCurrent();
   AtualizarPainelModerno();
}

void CriarSecao(string nome_base, int x, int y, string titulo)
{
   // Títulos com marcador visual para diferenciar cada módulo do dashboard.
   CriarTexto(nome_base + "_titulo", x + 12, y, "▸ " + titulo, Cor_Header, 8, "Arial Black");
}

//+------------------------------------------------------------------+
//| Painel RSI Dashboard — identidade visual própria                 |
//| Mantém a linguagem escura do painel original, mas usa módulos    |
//| de leitura de sinal, tendência e proteção financeira.            |
//+------------------------------------------------------------------+
void CriarPainelModerno()
{
   int x = Painel_X, y = Painel_Y;
   CriarObjetoPainel("painel_fundo", x, y, PAINEL_LARGURA, PAINEL_ALTURA, clrBlack);
   CriarObjetoPainel("painel_header", x, y, PAINEL_LARGURA, 3, Cor_Header);
   if(Mostrar_Botao_Reset)
      CriarBotao("btn_reset", x + PAINEL_LARGURA - 118, y + 45, 108, 22, "RESETAR", Cor_Botao, clrWhite);
   ChartRedraw();
}

void AtualizarPainelModerno()
{
   int x = Painel_X, y = Painel_Y;
   double saldo_atual = AccountInfoDouble(ACCOUNT_BALANCE);
   double capital_atual = AccountInfoDouble(ACCOUNT_EQUITY);
   double resultado_sessao = capital_atual - capital_inicial_sessao;
   double historico_sessao = CalcularHistoricoSessao();
   double lucro_posicoes = CalcularLucroEA();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   color cor_resultado = resultado_sessao >= 0 ? Cor_Positivo : Cor_Negativo;
   color cor_historico = historico_sessao >= 0 ? Cor_Positivo : Cor_Negativo;
   color cor_lucro = lucro_posicoes >= 0 ? Cor_Positivo : Cor_Negativo;
   color cor_rsi = rsi_atual <= RSI_Nivel_Sobrevenda ? Cor_Positivo : (rsi_atual >= RSI_Nivel_Sobrecompra ? Cor_Negativo : Cor_Alerta);
   color cor_tendencia = ask >= ma_atual ? Cor_Positivo : Cor_Negativo;
   int compras_ativas = ContarOrdens(POSITION_TYPE_BUY);
   string tf = EnumToString((ENUM_TIMEFRAMES)Period());
   StringReplace(tf, "PERIOD_", "");

   CriarTexto("txt_titulo", x+12, y+10, "FX RSI GRID", Cor_Header, 11, "Arial Black");
   CriarTexto("txt_simbolo", x+12, y+30, _Symbol+" / "+tf, Cor_Texto, 8, "Courier New");
   CriarTexto("txt_sessao_lbl", x+170, y+10, "INÍCIO DA SESSÃO", Cor_Texto, 7, "Arial");
   CriarTexto("txt_sessao_val", x+170, y+25, "$"+DoubleToString(capital_inicial_sessao, 2), Cor_Texto, 10, "Arial Black");
   CriarTexto("txt_historico_lbl", x+330, y+10, "HISTÓRICO DA SESSÃO", Cor_Texto, 7, "Arial");
   CriarTexto("txt_historico_val", x+330, y+25, (historico_sessao >= 0 ? "+$" : "-$")+DoubleToString(MathAbs(historico_sessao), 2), cor_historico, 10, "Arial Black");
   CriarTexto("txt_rsi_lbl", x+535, y+10, "RSI("+IntegerToString(RSI_Periodo)+")", Cor_Texto, 7, "Arial");
   CriarTexto("txt_rsi_val", x+535, y+25, DoubleToString(rsi_atual, 1), cor_rsi, 11, "Arial Black");
   CriarTexto("txt_compras_lbl", x+625, y+10, "COMPRAS", Cor_Texto, 7, "Arial");
   CriarTexto("txt_compras_val", x+625, y+25, IntegerToString(compras_ativas), Cor_Texto, 11, "Arial Black");
   CriarTexto("txt_lote_lbl", x+715, y+10, "LOTE", Cor_Texto, 7, "Arial");
   CriarTexto("txt_lote_val", x+715, y+25, DoubleToString(CalcularLoteAtual(), 2), Cor_Texto, 11, "Arial Black");
   CriarTexto("txt_saldo_lbl", x+805, y+10, "SALDO ATUAL", Cor_Texto, 7, "Arial");
   CriarTexto("txt_saldo_val", x+805, y+25, "$"+DoubleToString(saldo_atual, 2), Cor_Texto, 9, "Arial Bold");
   CriarTexto("txt_resultado_lbl", x+930, y+10, "RESULTADO", Cor_Texto, 7, "Arial");
   CriarTexto("txt_resultado_val", x+930, y+25, (resultado_sessao >= 0 ? "+$" : "-$")+DoubleToString(MathAbs(resultado_sessao), 2), cor_resultado, 10, "Arial Black");

   CriarTexto("txt_status_val", x+12, y+52, !grid_ja_ativado ? "AGUARDANDO ENTRADA" : "GRID EM EXECUÇÃO", !grid_ja_ativado ? Cor_Alerta : Cor_Positivo, 8, "Arial Black");
   CriarTexto("txt_tendencia", x+205, y+52, ask >= ma_atual ? "ACIMA DA MA" : "ABAIXO DA MA", cor_tendencia, 8, "Arial Black");
   CriarTexto("txt_protecao_status", x+350, y+52, Usar_Stop_Financeiro ? "PROTEÇÃO ATIVA" : "PROTEÇÃO OFF", Usar_Stop_Financeiro ? Cor_Positivo : Cor_Negativo, 8, "Arial Black");
   CriarTexto("txt_protecao_limites", x+515, y+52, "GAIN +$"+DoubleToString(Meta_Lucro_Sessao,0)+" | LOSS -$"+DoubleToString(Stop_Loss_Sessao,0), Cor_Texto, 8, "Courier New");
   CriarTexto("txt_flutuante", x+750, y+52, "FLUTUANTE "+(lucro_posicoes >= 0 ? "+$" : "-$")+DoubleToString(MathAbs(lucro_posicoes),2), cor_lucro, 8, "Arial Black");
   ChartRedraw(0);
}

double CalcularLucroEA()
{
   double lucro = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         lucro += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return lucro;
}

double CalcularHistoricoSessao()
{
   double resultado = 0.0;
   datetime fim = TimeCurrent();
   if(!HistorySelect(hora_inicio_sessao, fim)) return 0.0;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != Magic_Number) continue;

      resultado += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      resultado += HistoryDealGetDouble(ticket, DEAL_SWAP);
      resultado += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      resultado += HistoryDealGetDouble(ticket, DEAL_FEE);
   }
   return resultado;
}

int ContarOrdens(ENUM_POSITION_TYPE tipo)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == tipo) count++;
   }
   return count;
}

void CriarObjetoPainel(string nome, int x, int y, int largura, int altura, color cor, int corner = CORNER_LEFT_UPPER)
{
   if(ObjectFind(0, nome) >= 0) ObjectDelete(0, nome);
   ObjectCreate(0, nome, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nome, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nome, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, nome, OBJPROP_XSIZE, largura);
   ObjectSetInteger(0, nome, OBJPROP_YSIZE, altura);
   ObjectSetInteger(0, nome, OBJPROP_BGCOLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, nome, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   // O fundo fica atrás dos candles, evitando ocultar o gráfico.
   ObjectSetInteger(0, nome, OBJPROP_BACK, true);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
}

void CriarTexto(string nome, int x, int y, string texto, color cor, int tamanho, string fonte = "Arial", int corner = CORNER_LEFT_UPPER)
{
   if(ObjectFind(0, nome) >= 0) ObjectDelete(0, nome);
   ObjectCreate(0, nome, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nome, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nome, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, nome, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetString(0, nome, OBJPROP_FONT, fonte);
   ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, tamanho);
   ObjectSetString(0, nome, OBJPROP_TEXT, texto);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
}

void CriarBotao(string nome, int x, int y, int largura, int altura, string texto, color cor_fundo, color cor_texto)
{
   if(ObjectFind(0, nome) >= 0) ObjectDelete(0, nome);
   ObjectCreate(0, nome, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, nome, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nome, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, nome, OBJPROP_XSIZE, largura);
   ObjectSetInteger(0, nome, OBJPROP_YSIZE, altura);
   ObjectSetInteger(0, nome, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nome, OBJPROP_BGCOLOR, cor_fundo);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor_texto);
   ObjectSetString(0, nome, OBJPROP_TEXT, texto);
   ObjectSetString(0, nome, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, nome, OBJPROP_STATE, false);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
}

void DeletarTodosObjetos()
{
   string objetos[] = {
      "painel_fundo", "painel_header", "header_accent",
      "card_conta", "card_mercado", "card_ops", "card_protecao",
      "accent_conta", "accent_mercado", "accent_ops", "accent_protecao",
      "sec_conta_titulo", "sec_mercado_titulo", "sec_ops_titulo", "sec_protecao_titulo",
      "btn_reset", "txt_titulo", "txt_subtitulo", "txt_simbolo",
      "txt_sessao_lbl", "txt_sessao_val", "txt_historico_lbl", "txt_historico_val", "txt_flutuante",
      "txt_saldo_ini", "txt_saldo_ini_val", "txt_saldo_atu", "txt_saldo_atu_val", "txt_patrimonio", "txt_patrimonio_val", "txt_resultado", "txt_resultado_val",
      "txt_ask_bid", "txt_rsi_lbl", "txt_rsi_val", "txt_rsi_zona", "txt_ma_lbl", "txt_ma_val", "txt_tendencia", "pill_status", "txt_status_val",
      "txt_compras_lbl", "txt_compras_val", "txt_lote_lbl", "txt_lote_val", "txt_lucro_lbl", "txt_lucro_val", "txt_protecao_status", "txt_protecao_limites",
      "linha_banda_superior", "linha_banda_inferior", "linha_ma200"
   };
   for(int i = 0; i < ArraySize(objetos); i++) ObjectDelete(0, objetos[i]);
   for(int i = 0; i < 100; i++) ObjectDelete(0, "linha_grid_" + IntegerToString(i));
   ChartRedraw();
}
