package Nullarbor::Module::phylotree;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;
use Bio::TreeIO;
use Path::Tiny;

#...........................................................................................

sub name {
  return "Core SNP Phylogeny";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;

  my %ST_of;
  my $mlst = Nullarbor::Tabular::load(-file=>"$indir/report/mlst.csv", -sep=>",", -header=>1);  
  for my $row (@$mlst) {
    $ST_of{ $row->[0] } = $row->[2];
  }

  my %AMR_of;
  my $amr = Nullarbor::Tabular::load(-file=>"$indir/report/resistome.csv", -sep=>",", -header=>1);
  for my $row (@$amr) {
    $AMR_of{ $row->[0] } = $row->[1];
  }

  # To number nodes
  my %idx_of;
  my $tree_fn = "$indir/core.newick";
  my $in = Bio::TreeIO->new(-file=>$tree_fn, -format=>'newick');
  my $tree = $in->next_tree or die $!;
  my $count=0;
  for my $node ( $tree->get_root_node->get_all_Descendents ) {
    if ($node->is_Leaf) {
      $idx_of{ $node->id } = $count;
      $count++;
    }
  }
#  print STDERR Dumper(\%idx_of);
  
  # for embeddeding in HTML
  my $nwk = path($tree_fn)->slurp();
  chomp $nwk;

  my $aln = Bio::SeqIO->new(-file=>"$indir/core.aln", -format=>'fasta');
  $aln = $aln->next_seq;
  my $stats = sprintf "%d taxa, %d SNPs", scalar(@{$self->isolates}), $aln->length;

my $html=<<"HTML_TOP";
<div style="text-align: center;">$stats</div>
<div id="phylocanvas">  

<script type="application/javascript" src="https://cdn.rawgit.com/phylocanvas/phylocanvas-quickstart/v2.8.1/phylocanvas-quickstart.js"></script>
<script type="application/javascript">
var tree = Phylocanvas.createTree('phylocanvas', {
  alignLabels: true,
  lineWidth: 2,
  scalebar: { active: true, position: { bottom: 10, centre: 10 } },
});  
tree.on('error', function (event) { throw event.error; });
tree.on('loaded', function () { console.log('loaded phylocanvas'); });
tree.on('beforeFirstDraw', function () {
  tree.metadata.headerAngle = 60;
  tree.metadata.columns = [ 'ST', 'AMR', 'Order' ];
HTML_TOP

for my $label (sort keys %idx_of) {
  my $idx = $idx_of{$label};
  my $ST = $ST_of{$label} || '-';
  my $AMR = $AMR_of{$label} || '-';
  $html .=<<"EOLEAF";
  tree.leaves[$idx].data = { 
    Order: { label: '$idx', colour: 'white' },
    ST: { label: '$ST', colour: 'white' },
    AMR: { label: '$AMR', colour: 'white' },
  };
EOLEAF
}

my $ref = $idx_of{'Reference'};
$html .= "  tree.leaves[$ref].labelStyle.format = 'bold';\n";

$html.=<<"HTML_BOTTOM";
});
tree.load('$nwk');
tree.setTreeType('rectangular');
tree.setTextSize(16);
tree.setNodeSize(4);
tree.draw();

</script>
</div>
HTML_BOTTOM
  

  return $html;
}

1;

